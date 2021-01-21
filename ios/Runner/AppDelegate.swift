import UIKit
import Flutter
import CloverConnector

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var cloverChannel : FlutterMethodChannel!
    var cm: ConnectionManager!

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        cloverChannel = FlutterMethodChannel(name: "phan.dev/clover", binaryMessenger: controller.binaryMessenger)
        cloverChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
            // Note: this method is invoked on the UI thread.
            guard call.method == "connect" || call.method == "takePayment" else {
                result(FlutterMethodNotImplemented)
                return
            }
            if(call.method == "connect"){
                let endpoint = call.arguments as! String
                self?.connect(result: result, endpoint: endpoint)
            }
            else if(call.method == "takePayment"){
                let _amount = call.arguments as! String
                self?.takePayment(result: result, amount: _amount)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func connect(result: FlutterResult, endpoint: String) {
        var cc:ICloverConnector?
        cm = ConnectionManager(cloverConnector: cc, channel: cloverChannel)
        cm.connect(endpoint: endpoint)
        result("Connecting")
    }

    private func takePayment(result: FlutterResult, amount: String) {
        var _amount: String = ""
        if amount.firstIndex(of: ".") != nil {
            _amount = amount.replacingOccurrences(of: ".", with: "")
        } else {
            _amount += amount + "00"
        }
        cm.doSale(amount: Int(_amount)!)
        result("Processing")
    }
}

class ConnectionManager : DefaultCloverConnectorListener, PairingDeviceConfiguration {
    var cc:ICloverConnector?

    var myToken: String?

    var myChannel: FlutterMethodChannel
    init(cloverConnector: ICloverConnector?, channel: FlutterMethodChannel){
        self.myChannel = channel
        super.init(cloverConnector: cc)
    }

    func connect(endpoint: String) {
        // load from previous pairing, or nil will force/require
        // a new pairing with the device
        let savedAuthToken = loadAuthToken()

        //let endpoint = "wss://192.168.1.137:12345/remote_pay"
        let config = WebSocketDeviceConfiguration(endpoint: endpoint,
            remoteApplicationID: "phan.dev",
            posName: "Flutter POS", posSerial: "POS-123",
            pairingAuthToken: savedAuthToken, pairingDeviceConfiguration: self)

        cc = CloverConnectorFactory.createICloverConnector(config: config)
        cc?.addCloverConnectorListener(self)
        cc?.initializeConnection()
    }

    func doSale(amount: Int) {
        cc?.showMessage("Payment Processing")
        // if onDeviceReady has been called
        let externalId = String(arc4random())
        let saleRequest = SaleRequest(amount: amount, externalId: externalId)
        // configure other properties of SaleRequest
        cc?.sale(saleRequest)
    }

    // store the token to be loaded later by loadAuthToken
    func saveAuthToken(token:String) {
        myToken = token;
    }
    func loadAuthToken() -> String? { return myToken }


    // PairingDeviceConfiguration
    func onPairingCode(_ pairingCode: String) {
        // display pairingCode to user, to be entered on the Clover Mini
        myChannel.invokeMethod("getCode", arguments: pairingCode)
    }

    func onPairingSuccess(_ authToken: String) {
        // pairing is successful
        // save this authToken to pass in to the config for future connections
        // so pairing will happen automatically
        saveAuthToken(token: authToken)
        myChannel.invokeMethod("getConnectionStatus", arguments: "onPairingSuccess")
    }


    // DefaultCloverConnectorListener

    // called when device is disconnected
    override func onDeviceDisconnected() {
        myChannel.invokeMethod("getConnectionStatus", arguments: "onDeviceDisconnected")
    }

    // called when device is connected, but not ready for requests
    override func onDeviceConnected() {
        myChannel.invokeMethod("getConnectionStatus", arguments: "onDeviceConnected")
    }

    // called when device is ready to take requests. Note: May be called more than once
    override func onDeviceReady(_ info:MerchantInfo){
        myChannel.invokeMethod("getConnectionStatus", arguments: "onDeviceReady")
    }

    // required if Mini wants the POS to verify a signature
    override func onVerifySignatureRequest(_ signatureVerifyRequest: VerifySignatureRequest) {
        //present signature to user, then
        // acceptSignature(...) or rejectSignature(...)
        cc?.acceptSignature(signatureVerifyRequest)
        myChannel.invokeMethod("getPaymentStatus", arguments: "onVerifySignatureRequest")
    }

    // required if Mini wants the POS to verify a payment
    override func onConfirmPaymentRequest(_ request: ConfirmPaymentRequest) {
        //present 1 or more challenges to user, then
        cc?.acceptPayment(request.payment!)
        // or
        // cc?.rejectPayment(...)
        myChannel.invokeMethod("getPaymentStatus", arguments: "onConfirmPaymentRequest")
    }

    // override other callback methods
    override func onSaleResponse(_ response:SaleResponse) {
        if response.success {
            // sale successful and payment is in the response (response.payment)
            myChannel.invokeMethod("getPaymentStatus", arguments: "sale successful")
        } else {
            // sale failed or was canceled
            myChannel.invokeMethod("getPaymentStatus", arguments: "sale failed or was canceled")
        }
    }

    override func onAuthResponse(_ response:AuthResponse) {}
    override func onPreAuthResponse(_ response:PreAuthResponse) {}

    // will provide UI information about the activity on the Mini,
    // and may provide input options for the POS to select some
    // options on behalf of the customer
    override func onDeviceActivityStart(_ deviceEvent:CloverDeviceEvent){} // see CloverConnectorListener.swift for example of calling invokeInputOption from this callback
    override func onDeviceActivityEnd(_ deviceEvent:CloverDeviceEvent){}
    // etc.

}
