//
//  ViewController.swift
//  claude
//
//  Created by Tim Tully on 3/5/24.
//

import UIKit
import WebKit
import LDSwiftEventSource
import SideMenu
import Speech
import ProgressHUD

enum MicroPhoneState {
    case MIC_NOT_INIT
    case MIC_ON
    case MIC_OFF
}

extension String {
    func makeHTMLfriendly() -> String {
        var finalString = ""
        for char in self {
            for scalar in String(char).unicodeScalars {
                finalString.append("&#\(scalar.value)")
            }
        }
        return finalString
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexFormatted = hexFormatted.replacingOccurrences(of: "#", with: "")
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

class ViewController: UIViewController, EventHandler {
    
    var ANTHROPIC_KEY:String = "";
    
    let ANT_URI = "https://api.anthropic.com/v1/messages";
    
    weak var sidemenu:SideMenuNavigationController!;
    var micState:MicroPhoneState = .MIC_NOT_INIT
    var audioEngine = AVAudioEngine()
    var curHTML:String = "";
    var curDivId:String = "";
    var curRecognition:SFSpeechRecognitionTask = SFSpeechRecognitionTask()
    var html:String = """

    
<!DOCTYPE html><html lang=\"en\">
<head>
    <style>
        .response{border-radius: 10px; border: 3px solid #000000;}
        .dark{color:#eeeeee;background-color:#222222;}
    </style>
    <meta charset=\"utf-8\">
    <!-- <meta name=\"HandheldFriendly\" content=\"True\"> -->
    <meta http-equiv=\"cleartype\" content=\"on\"><meta name=\"MobileOptimized\" content=\"320\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">
</head>
<body id=\"body\" style=\"margin-left:5px;padding-left:5px;font-size:16px; font: Gotham, Arial, sans-serif;\"><br/>
<div id=\"results\"></div>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script>
function setBodyClass(cl){document.getElementById(\"body\").className = cl;}
function inject(h, div_id){
    document.getElementById(div_id).innerHTML += h;
    window.scrollTo(0, document.body.scrollHeight);
}
function renderMarkdown(html, cur_div_id){
    marked.use({html:true, gfm:true});
 
      //document.getElementById(cur_div_id).innerHTML = marked.parse('&nbsp;' + html);
      document.getElementById(cur_div_id).innerHTML = marked.parse(html);
      
        return 42;
}
</script>
</body>
</html>
"""
    
    var es:EventSource?;
    
    @IBOutlet weak var tf: UITextField!
    
    @IBOutlet weak var webview: WKWebView!
    
    @IBOutlet weak var submitButton: UIButton!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Check the segue identifier if there are multiple segues
        if segue.identifier == "hamburger_select" {
            // Downcast the destination ViewController to your specific class
            if let destinationVC = segue.destination as? SideMenuNavigationController {
                // Pass data to the destinationVC
                //destinationVC.someProperty = dataYouWantToPass
                self.sidemenu = destinationVC
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let config = ConfigManager()
        self.ANTHROPIC_KEY = config?.value(forKey: "ANTHROPIC_KEY") as! String;
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                // Permission granted
                break
            case .denied, .restricted, .notDetermined:
                // Handle the error: inform the user they can't use this feature
                break
            @unknown default:
                break
            }
        }
        
        let hdb = HistoryDB.shared;
        let db:OpaquePointer = hdb.openTable();
        HistoryDB.shared.createTable(db: db);
        // Do any additional setup after loading the view.
        webview.loadHTMLString(html, baseURL: nil)
        tf.backgroundColor = .white
        self.view.backgroundColor = UIColor(hex:"#f0eee5");
        NotificationCenter.default.addObserver(self, selector: #selector(handleSearchEvent), name: .RUN_SEARCH, object: nil)
        
    }
    
    @objc func handleSearchEvent(notification: Notification) {
        if let userInfo = notification.userInfo as? [String: Any] {
            let data = userInfo["qt"] as? String // Change the type according to the actual data type
            // Use the extracted data
            doQuery(q:data!)
        }
    }
    
    
    func setTheme(){
        let functionName = "setBodyClass"
        var arguments:[String] = []
        if self.traitCollection.userInterfaceStyle == .dark {
            arguments = ["'dark'"]
        } else {
            arguments = ["'light'"]
        }
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        let script = "\(functionName)(\(argumentsString));"
        webview.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            } else {
                if let result = result {
                    print("Function returned: \(result)")
                }
            }
        }
    }
    
    func injectHTML(html:String, div_id:String) {
        let functionName = "inject"
        let newhtml = "'" + html + "'"
        let arguments = [newhtml, "'" + div_id + "'"] // Pass any arguments required by the function
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        
        let script = "\(functionName)(\(argumentsString));"

        webview.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            } else {
                if let result = result {
                    print("Function returned: \(result)")
                }
            }
        }
    }
    
    func renderMarkdown(h:String, div_id:String){
        
        let functionName = "renderMarkdown"
        let newhtml = "'" + h + "'"
        let arguments = [newhtml, "'" + div_id + "'"] // Pass any arguments required by the function
        let argumentsString = arguments.map { String($0) }.joined(separator: ",")
        
        let script = "\(functionName)(\(argumentsString));"
        webview.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error calling JavaScript function: \(error.localizedDescription)")
            } else {
                if let result = result {
                    print("Function returned: \(result)")
                }
            }
        }
    }
    
    @IBAction func query(sender: UIButton) {
        let q = tf.text;
        doQuery(q:q!);
    }
    
    func micHud(on:Bool) {
        DispatchQueue.main.async { () -> Void in
            if (on) {
                ProgressHUD.animate("Please wait...", .horizontalBarScaling)
            }
            else{
                print("Turning mic off")
                ProgressHUD.remove()
            }
        }
    }
    
    
    @IBAction func doVoiceQuery(sender: UIButton) {
        print("CLICK VOICE")
        let inputNode = audioEngine.inputNode
        
        switch micState {
        case .MIC_ON:
            print("MIC IS ON")
            //audioEngine.stop()
            audioEngine.stop()
            inputNode.removeTap(onBus:0)
            self.micState = .MIC_OFF;
            micHud(on:false)
            self.curRecognition.finish()
            doQuery(q: self.tf.text!)
            return;
        case .MIC_OFF, .MIC_NOT_INIT:
            print("MIC IS OFF")
            self.micState = .MIC_ON
            micHud(on:true)
            break;
        }
        
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Handle the error
            print("Error in first try cach")
            micHud(on:false)
            self.micState = .MIC_OFF
        }
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionRequest.shouldReportPartialResults = true
        
        curRecognition = (speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [self] (result, error) in
            var isFinal = false
            
            if let result = result {
                // Update your UI with the results
                let bestString = result.bestTranscription.formattedString
                isFinal = result.isFinal
                self.tf.text = bestString
                // Do something with the recognized text
            }
            if error != nil || isFinal {
                // Stop the audioEngine (microphone) and the recognition task
                print(error as Any)
                audioEngine.stop()
                self.micState = .MIC_OFF
                self.micHud(on:false)
                self.curRecognition.finish()
                inputNode.removeTap(onBus: 0)
            }
        }))!
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("COULDNT START")
            micHud(on:false)
            self.micState = .MIC_OFF

        }
    }
    
    func currentSelectedModelName() -> String {
        let cur = UserDefaults.standard.string(forKey: Constants.PREFERENCE_MODEL_SELECTED)
        if (cur == nil || cur == "Opus"){
            return Constants.MODEL_NAME_OPUS
        }
        else if(cur == "Sonnet"){
            return Constants.MODEL_NAME_SONNET
        }
        return Constants.MODEL_NAME_HAIKU
    }
    
    func doQuery(q:String) {
        let uri = URL(string:ANT_URI);
        print("Using Model \(currentSelectedModelName())")
        var config = EventSource.Config.init(handler: self, url: uri!);
        config.headers = ["Content-type": "application/json", "x-api-key":ANTHROPIC_KEY, "anthropic-version":"2023-06-01", "anthropic-beta":"messages-2023-12-15" ];
        config.method = "POST";
        let postData2:[String:Any] = ["model": currentSelectedModelName(), "max_tokens": 4096, "stream":true, "messages": [["role": "user", "content": q]]];
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData2, options: []) else {
            print("Error serializing JSON")
            return
        }
        
        config.body = jsonData
        config.idleTimeout = 600.0
        
        self.curDivId = generateRandomString(length: 10)
        
        DispatchQueue.main.async { () -> Void in
            self.setTheme()
            print("Setting div \(self.curDivId)")
            print("</h2><div id=\"\(self.curDivId)\"></div>")
            self.injectHTML(html: "<hr><h2>" + q + "</h2><div id=\"\(self.curDivId)\"></div>", div_id:"results")
            self.view.endEditing(true)

        }
        
        self.es = EventSource(config: config);
        DispatchQueue.global(qos: .utility).async { [weak self] () -> Void in
            self!.es!.start()
            HistoryDB.shared.insertQuery(query: q)
        }
        
    }
    
    func jsonToDict(jsonString:String) -> [String:Any]{
        let jsonData = jsonString.data(using: .utf8)
        
        do {
            
            if let dictionary = try JSONSerialization.jsonObject(with: jsonData!, options: []) as? [String: Any] {
                // Now `dictionary` is a [String: Any] dictionary.
                return dictionary
            } else {
                print("The JSON is not a dictionary.")
            }
        } catch {
            print("Error deserializing JSON: \(error.localizedDescription)")
        }
        return [:]
    }
    
    
    func onMessage(eventType: String, messageEvent: MessageEvent){
        let data = messageEvent.data;
        let data_obj = self.jsonToDict(jsonString: data)
        if (data_obj["type"] as! String == "content_block_delta") {
            let delta = data_obj["delta"] as! [String:Any];
            
            var newhtml = delta["text"] as! String
            
            newhtml = newhtml.replacingOccurrences(of: "\n", with: "\\n")
            newhtml = newhtml.replacingOccurrences(of: "'", with: "&#39;")
            
            DispatchQueue.global(qos: .utility).async { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                DispatchQueue.main.async { [self] () -> Void in
                    strongSelf.injectHTML(html: newhtml, div_id:self!.curDivId)
                }
            }
            curHTML += newhtml;
        }
    }
    func onOpened(){}
    func onClosed(){
        self.es?.stop()
        
        let curHTMLCopy = curHTML // make copy to stop race on curHTML
        let divId = curDivId
        DispatchQueue.main.async { [self] () -> Void in
            self.renderMarkdown(h:curHTMLCopy, div_id:divId)
        }
        self.curDivId = ""
        curHTML = "";
    }
    func onComment(comment: String){}
    func onError(error: Error){}
    
    func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        
        for _ in 0..<length {
            let randomIndex = Int(arc4random_uniform(UInt32(characters.count)))
            let randomCharacter = characters.index(characters.startIndex, offsetBy: randomIndex)
            randomString.append(characters[randomCharacter])
        }
        
        return randomString
    }
}

