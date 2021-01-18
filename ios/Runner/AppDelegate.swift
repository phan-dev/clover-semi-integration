import UIKit
import Flutter
import CloverConnector

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let cloverChannel = FlutterMethodChannel(name: "phan.dev/clover", binaryMessenger: controller.binaryMessenger)
        cloverChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
            // Note: this method is invoked on the UI thread.
            guard call.method == "getConnection" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.receiveConnectionStatus(result: result)
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func receiveConnectionStatus(result: FlutterResult) {
        var cc:ICloverConnector?
        var cm = ConnectionManager(cloverConnector: cc)
        cm.connect()
        result(cm._pairingCode)
    }
}

class ConnectionManager : DefaultCloverConnectorListener, PairingDeviceConfiguration {
    var cc:ICloverConnector?

    var _pairingCode: String = "N/A"
    func connect() {
        // load from previous pairing, or nil will force/require
        // a new pairing with the device
        let savedAuthToken = loadAuthToken()

        let config = WebSocketDeviceConfiguration(endpoint: "wss://192.168.1.186:12345/remote_pay",
            remoteApplicationID: "com.yourcompany.pos.app:4.3.5",
            posName: "RegisterApp", posSerial: "ABC-123",
            pairingAuthToken: savedAuthToken, pairingDeviceConfiguration: self)

        cc = CloverConnectorFactory.createICloverConnector(config: config)
        cc?.addCloverConnectorListener(self)
        cc?.initializeConnection()
    }

    func doSale() {
        // if onDeviceReady has been called
        let saleRequest = SaleRequest(amount: 1743, externalId: "bc54de43f3")
        // configure other properties of SaleRequest
        cc?.sale(saleRequest)
    }

    // store the token to be loaded later by loadAuthToken
    func saveAuthToken(token:String) {}
    func loadAuthToken() -> String? { return nil }


    // PairingDeviceConfiguration
    func onPairingCode(_ pairingCode: String) {
        // display pairingCode to user, to be entered on the Clover Mini

        self._pairingCode = pairingCode
        print("Pairing Code: " + pairingCode)
        debugPrint("Pairing Code: " + pairingCode)
    }

    func onPairingSuccess(_ authToken: String) {
        // pairing is successful
        // save this authToken to pass in to the config for future connections
        // so pairing will happen automatically
        saveAuthToken(token: authToken)
    }


    // DefaultCloverConnectorListener

    // called when device is disconnected
    override func onDeviceDisconnected() {}

    // called when device is connected, but not ready for requests
    override func onDeviceConnected() {}

    // called when device is ready to take requests. Note: May be called more than once
    override func onDeviceReady(_ info:MerchantInfo){}

    // required if Mini wants the POS to verify a signature
    override func onVerifySignatureRequest(_ signatureVerifyRequest: VerifySignatureRequest) {
        //present signature to user, then
        // acceptSignature(...) or rejectSignature(...)
    }

    // required if Mini wants the POS to verify a payment
    override func onConfirmPaymentRequest(_ request: ConfirmPaymentRequest) {
        //present 1 or more challenges to user, then
        cc?.acceptPayment(request.payment!)
        // or
        // cc?.rejectPayment(...)
    }

    // override other callback methods
    override func onSaleResponse(_ response:SaleResponse) {
        if response.success {
            // sale successful and payment is in the response (response.payment)
        } else {
            // sale failed or was canceled
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
