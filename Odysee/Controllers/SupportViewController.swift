//
//  SupportVIewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 07/12/2020.
//

import UIKit

class SupportViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, WalletBalanceObserver {
    var channels: [Claim] = []
    var claim: Claim? = nil
    let keyBalanceObserver = "support_vc"
    let currencyFormatter = NumberFormatter()
    
    @IBOutlet weak var walletBalanceLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var tipValueSegment: UISegmentedControl!
    @IBOutlet weak var tipValueField: UITextField!
    @IBOutlet weak var tipButton: UIButton!
    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var channelPickerView: UIPickerView!
    @IBOutlet weak var loadingSendSupportView: UIActivityIndicatorView!
    
    var tipCreditAmount: Decimal = 5
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.addWalletObserver(key: keyBalanceObserver, observer: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.removeWalletObserver(key: keyBalanceObserver)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        currencyFormatter.roundingMode = .up
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.locale = Locale.current
        
        registerForKeyboardNotifications()
        checkCreditAmount()
    
        if Lbry.walletBalance != nil {
            balanceUpdated(balance: Lbry.walletBalance!)
        }
        
        let anonymousClaim: Claim = Claim()
        anonymousClaim.name = "Anonymous"
        anonymousClaim.claimId = "anonymous"
        channels.append(anonymousClaim)
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        contentViewBottomConstraint.constant = kbSize.height - 36
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        contentViewBottomConstraint.constant = 0
    }
    
    func checkCreditAmount() {
        segmentValueChanged(tipValueSegment)
    }
    
    @IBAction func segmentValueChanged(_ sender: UISegmentedControl) {
        let custom = tipValueSegment.selectedSegmentIndex == 4
        tipValueField.isHidden = !custom
        if !custom {
            tipValueField.text = ""
        }
        switch (tipValueSegment.selectedSegmentIndex) {
        case 0:
            tipCreditAmount = 5
            break
        case 1:
            tipCreditAmount = 25
            break
        case 2:
            tipCreditAmount = 100
            break
        case 3:
            tipCreditAmount = 1000
            break
        default:
            // other
            tipCreditAmount = 0
            tipValueField.becomeFirstResponder()
            break
        }
        
        if (tipCreditAmount == 0) {
            tipButton.setTitle(String.localized("Tip credits"), for: .normal)
            return
        }
        
        tipButton.setTitle(String(format: String.localized("Tip %@ credits"), currencyFormatter.string(for: tipCreditAmount as NSDecimalNumber)!), for: .normal)
    }
    
    @IBAction func tipFieldTextChanged(_ sender: UITextField) {
        if tipValueSegment.selectedSegmentIndex != 4 {
            return
        }
        
        let inputAmount = Decimal(string: tipValueField.text!)
        if inputAmount != nil {
            tipButton.setTitle(String(format: String.localized(inputAmount == 1 ? "Tip %@ credit" : "Tip %@ credits"), currencyFormatter.string(for: inputAmount as NSDecimalNumber?)!), for: .normal)
        }
    }
    
    @IBAction func tipButtonTapped(_ sender: UIButton) {
        if claim == nil {
            // invalidate state, shouldn't happen
            showError(message: String.localized("No claim to support. Please dismiss the interface and try again."))
            return
        }
        
        var amount: Decimal? = tipCreditAmount
        if tipValueSegment.selectedSegmentIndex == 4 {
            // validate free-form input
            amount = Decimal(string: tipValueField.text!)
        }
        
        if (amount == nil) {
            showError(message: String.localized("Please enter a valid amount to donate"))
            return
        }
        
        if (amount! > Lbry.walletBalance!.available!) {
            showError(message: String.localized("Insufficient funds"))
            return
        }
        
        // verify first with an alert
        let alert = UIAlertController(title: String.localized("Confirm tip?"), message: String.localized("Are you sure you want to tip this creator?"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
            self.confirmSendTip(amount: amount!)
        }))
        alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))
        
        present(alert, animated: true, completion: nil)
    }
    
    func confirmSendTip(amount: Decimal) {
        tipButton.isEnabled = false
        loadingSendSupportView.isHidden = false
        
        var params = Dictionary<String, Any>()
        params["blocking"] = true
        params["claim_id"] = claim?.claimId!
        params["amount"] = Helper.sdkAmountFormatter.string(from: amount as NSDecimalNumber)
        params["tip"] = true
        // TODO: params["channel_id"]
        
        Lbry.apiCall(method: Lbry.methodSupportCreate, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                return
            }
            
            DispatchQueue.main.async {
                self.showMessage(message: String.localized("You sent a tip!"))
                self.tipButton.isEnabled = true
                self.loadingSendSupportView.isHidden = true
                self.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        })
    }
    
    @IBAction func anywhereInContentViewTapped(_ sender: Any) {
        tipValueField.resignFirstResponder()
    }
    
    @IBAction func anywhereTapped(_ sender: Any) {
        tipValueField.resignFirstResponder()
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return channels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return channels[row].name
    }
    
    func balanceUpdated(balance: WalletBalance) {
        walletBalanceLabel.text = Helper.shortCurrencyFormat(value: balance.available)
    }
    
    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
