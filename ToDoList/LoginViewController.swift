import UIKit
import AuthenticationServices  // Sign in with Apple (opsiyonel)
import CryptoKit
import WebKit
import SwiftUI

#Preview {
  ViewControllerPreview {
    LoginViewController()
  }
}

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class LoginViewController: UIViewController {

    // MARK: - Localization helper
    private func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func Lf(_ key: String, _ fallback: String) -> String {
        let v = NSLocalizedString(key, comment: "")
        return (v == key) ? fallback : v
    }

    // MARK: - Apply localized texts (Login)
    private func applyLocalizedTexts_Login() {
        // Subtitle
        subtitleLabel.text = L("login.subtitle")

        // Text fields
        emailField.placeholder = L("login.email.placeholder")
        passwordField.placeholder = L("login.password.placeholder")

        // Primary button
        signInButton.setTitle(L("login.signin"), for: .normal)

        // Google button (UIButton.Configuration title)
        if var cfg = googleButton.configuration {
            cfg.title = L("login.google")
            googleButton.configuration = cfg
        }

        // Divider center label: "or continue with"
        if let h = divider.arrangedSubviews.compactMap({ $0 as? UILabel }).first {
            h.text = L("login.orcontinue")
        }

        // Bottom helper labels
        registerLabel.text = L("login.noaccount")
        footerLabel.text = L("login.footer")
    }

    // MARK: - UI
    private let scroll = UIScrollView()
    private let content = UIStackView()

    // Apple Sign In nonce (replay-attack koruması)
    private var currentNonce: String?

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AppLogo")) // yoksa SF Symbol kullan
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        iv.heightAnchor.constraint(equalToConstant: 84).isActive = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Taskly"
        lb.font = .systemFont(ofSize: 32, weight: .bold)
        lb.textAlignment = .center
        return lb
    }()

    private let subtitleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Hızlı, sade ve odaklı görev yönetimi"
        lb.font = .preferredFont(forTextStyle: .subheadline)
        lb.textColor = .secondaryLabel
        lb.textAlignment = .center
        return lb
    }()

    private let emailField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "E-posta"
        tf.autocapitalizationType = .none
        tf.keyboardType = .emailAddress
        tf.returnKeyType = .next
        tf.clearButtonMode = .whileEditing
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.backgroundColor = .secondarySystemBackground
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        tf.setLeftPadding(14)
        return tf
    }()

    private let passwordField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Şifre"
        tf.isSecureTextEntry = true
        tf.returnKeyType = .done
        tf.clearButtonMode = .whileEditing
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.backgroundColor = .secondarySystemBackground
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        tf.setLeftPadding(14)
        return tf
    }()

    private let signInButton: UIButton = {
        let bt = UIButton(type: .system)
        bt.setTitle("Giriş Yap", for: .normal)
        bt.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        bt.backgroundColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        bt.tintColor = .white
        bt.layer.cornerRadius = 12
        bt.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return bt
    }()

    private let divider: UIStackView = {
        let l = UIView(); l.backgroundColor = .separator; l.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let r = UIView(); r.backgroundColor = .separator; r.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let lbl = UILabel()
        lbl.text = "veya bununla devam et"
        lbl.font = .preferredFont(forTextStyle: .footnote)
        lbl.textColor = .secondaryLabel
        let h = UIStackView(arrangedSubviews: [l, lbl, r])
        h.axis = .horizontal
        h.spacing = 12
        h.alignment = .center
        l.widthAnchor.constraint(equalTo: r.widthAnchor).isActive = true
        return h
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        // Always visible on black background: white border + white text
        let b = ASAuthorizationAppleIDButton(type: .signIn, style: .whiteOutline)
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true
        b.cornerRadius = 12
        return b
    }()

    private let googleButton: UIButton = {
        let bt = UIButton(type: .system)
        var cfg = UIButton.Configuration.tinted()
        cfg.baseBackgroundColor = .systemBackground
        cfg.baseForegroundColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        cfg.cornerStyle = .large
        cfg.title = "Google ile devam et"
        cfg.image = UIImage(systemName: "globe")
        cfg.imagePadding = 8
        bt.configuration = cfg
        bt.layer.borderWidth = 1
        bt.layer.borderColor = UIColor.separator.cgColor
        bt.layer.cornerRadius = 12
        bt.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return bt
    }()

    private let footerLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Devam ederek Gizlilik Politikası ve Kullanım Şartları’nı kabul etmiş olursun."
        lb.font = .preferredFont(forTextStyle: .caption2)
        lb.textColor = .secondaryLabel
        lb.numberOfLines = 0
        lb.textAlignment = .center
        return lb
    }()

    private let registerLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Hesabın yok mu? Kayıt Ol"
        lb.font = .preferredFont(forTextStyle: .footnote)
        lb.textColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        lb.textAlignment = .center
        lb.isUserInteractionEnabled = true
        return lb
    }()

    private let languageButton: UIButton = {
        let b = UIButton(type: .system)
        let appBlue = (UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1))
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = NSLocalizedString("settings.language", comment: "")
            config.image = UIImage(systemName: "globe")
            config.imagePadding = 6
            config.baseForegroundColor = appBlue
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12)
            config.background.backgroundColor = .secondarySystemBackground
            config.background.cornerRadius = 10
            b.configuration = config
        } else {
            if let img = UIImage(systemName: "globe") {
                b.setImage(img, for: .normal)
                b.tintColor = appBlue
            }
            b.setTitle(NSLocalizedString("settings.language", comment: ""), for: .normal)
            b.setTitleColor(appBlue, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 12)
            b.layer.cornerRadius = 10
            b.backgroundColor = .secondarySystemBackground
        }
        
        b.accessibilityIdentifier = "login.language.button"
        return b
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) { overrideUserInterfaceStyle = .dark }
        view.backgroundColor = .black
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupLayout()
        // Brand title styling: "Task" normal, "ly" AppBlue (same font)
        let appBlue = UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        let baseFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let taskPart = NSAttributedString(string: "Task", attributes: [
            .font: baseFont,
            .foregroundColor: UIColor.label
        ])
        let lyPart = NSAttributedString(string: "ly", attributes: [
            .font: baseFont,
            .foregroundColor: appBlue
        ])
        let brandTitle = NSMutableAttributedString()
        brandTitle.append(taskPart)
        brandTitle.append(lyPart)
        // Localize all visible texts for current iOS language
        applyLocalizedTexts_Login()
        titleLabel.attributedText = brandTitle
        titleLabel.accessibilityLabel = "Taskly"
        signInButton.addTarget(self, action: #selector(didTapEmailSignIn), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(didTapApple), for: .touchUpInside)
        googleButton.addTarget(self, action: #selector(didTapGoogle), for: .touchUpInside)

        // Klavye için
        emailField.delegate = self
        passwordField.delegate = self
        registerForKeyboardNotifications()

        // Tap anywhere to dismiss keyboard (same as Register)
        let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapDismiss)

        // Allow interactive keyboard dismissal when scrolling (same as Register)
        scroll.keyboardDismissMode = .interactive
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(openRegister))
        registerLabel.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(didRegister(_:)), name: .tasklyDidRegister, object: nil)

        // Language button (same behavior as Settings → Language)
        languageButton.addTarget(self, action: #selector(didTapLanguage), for: .touchUpInside)
        view.addSubview(languageButton)
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            languageButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            languageButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scroll.addSubview(content)
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        let spacer1 = UIView(); spacer1.heightAnchor.constraint(equalToConstant: 8).isActive = true
        let spacer2 = UIView(); spacer2.heightAnchor.constraint(equalToConstant: 6).isActive = true
        let socialStack = UIStackView(arrangedSubviews: [appleButton, googleButton])
        socialStack.axis = .vertical
        socialStack.spacing = 10

        [logoView, titleLabel, subtitleLabel, spacer1, emailField, passwordField, signInButton, divider, socialStack, spacer2, registerLabel, footerLabel]
            .forEach { content.addArrangedSubview($0) }
    }

    // MARK: - Actions
    @objc private func didTapEmailSignIn() {
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pass = passwordField.text ?? ""
        // Kayıt/giriş için minimum 6 karakter şifre kuralı
        guard email.contains("@"), pass.count >= 6 else {
            showAlert(
                Lf("auth.error.title", "Error"),
                Lf("auth.validation.missing", "Please enter a valid email and a password of at least 6 characters.")
            )
            return
        }

        #if canImport(FirebaseAuth)
        // Gerçek giriş: Firebase Authentication
        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] result, error in
            guard let self = self else { return }
            if let err = error as NSError? {
                // Kullanıcı bulunamadı veya şifre hatalı senaryolarını ayrıştır
                if err.code == AuthErrorCode.userNotFound.rawValue {
                    let ac = UIAlertController(
                        title: Lf("auth.userNotFound.title", "Account Not Found"),
                        message: Lf("auth.userNotFound.message", "No account exists with this email. Would you like to sign up?"),
                        preferredStyle: .alert
                    )
                    ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
                    ac.addAction(UIAlertAction(title: L("register.signup"), style: .default, handler: { _ in
                        self.openRegister()
                    }))
                    self.present(ac, animated: true)
                } else if err.code == AuthErrorCode.wrongPassword.rawValue {
                    self.showAlert(
                        Lf("auth.wrongPassword.title", "Incorrect Password"),
                        Lf("auth.wrongPassword.message", "Please check your password and try again.")
                    )
                } else {
                    self.showAlert(Lf("auth.error.title", "Sign-in Error"), err.localizedDescription)
                }
                return
            }

            // Başarılı giriş
            let name = result?.user.displayName ?? email.components(separatedBy: "@").first!.capitalized
            let user = SettingsViewController.AppUser(
                name: name,
                email: email,
                avatar: UIImage(systemName: "person.crop.circle.fill")
            )
            SettingsViewController.UserSession.shared.currentUser = user
            self.dismiss(animated: true)
        }
        #else
        // FirebaseAuth henüz entegre edilmemişse kullanıcıyı bilgilendir; lokal sahte giriş YAPMA
        showAlert("Giriş Kullanılamıyor", "E-posta ile giriş için FirebaseAuth eklenmeli. Lütfen önce kayıt ol veya Google/Apple ile giriş seçeneklerini kullan.")
        #endif
    }

    @objc private func didTapApple() {
        if #available(iOS 13.0, *) {
            startSignInWithAppleFlow()
        } else {
            showAlert(
                Lf("auth.unsupported.title", "Unsupported"),
                Lf("auth.unsupported.message", "This feature requires iOS 13 or later.")
            )
        }
    }

    @objc private func didTapGoogle() {
#if canImport(GoogleSignIn)
        // iOS 13+ Google Sign-In (SDK v7+) — Firebase ile
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showAlert("Google Sign-In", "clientID bulunamadı. GoogleService-Info.plist dosyasını kontrol et.")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                print("Google Sign-In error:", error)
                self.showAlert("Giriş Hatası", error.localizedDescription)
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.showAlert("Giriş Hatası", "Google kimlik belirteci alınamadı.")
                return
            }
            let accessToken = user.accessToken.tokenString

            #if canImport(FirebaseAuth)
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                if let error = error {
                    print("Firebase Google sign-in hata:", error)
                    self.showAlert("Giriş Hatası", error.localizedDescription)
                    return
                }

                // Profil bilgilerini (ad/e‑posta) Firestore'a yaz (opsiyonel, Apple ile aynı mantık)
                #if canImport(FirebaseFirestore)
                if let uid = Auth.auth().currentUser?.uid {
                    let db = Firestore.firestore()
                    var profile: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
                    if let email = authResult?.user.email ?? user.profile?.email {
                        profile["email"] = email
                    }
                    let display = authResult?.user.displayName ?? user.profile?.name
                    if let name = display { profile["displayName"] = name }
                    db.collection("users").document(uid).setData(["profile": profile], merge: true)
                }
                #endif

                NotificationCenter.default.post(name: .tasklyDidLogin, object: nil)
                self.dismiss(animated: true)
            }
            #else
            self.showAlert("Firebase Eksik", "FirebaseAuth modülü ekli değil. Lütfen FirebaseAuth'u hedefe bağla.")
            #endif
        }
#else
        showAlert("Google Sign-In", "GoogleSignIn SDK ekli değil. Swift Package Manager ile 'GoogleSignIn' paketini ekleyin.")
#endif
    }

    // MARK: - Apple Sign In Flow
    @available(iOS 13.0, *)
    private func startSignInWithAppleFlow() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        // Nonce üret ve hash'ini isteğe ekle
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // Rastgele nonce üretimi
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            if status != errSecSuccess {
                fatalError("Nonce üretilemedi. OSStatus: \(status)")
            }
            for b in bytes where remaining > 0 {
                if b < charset.count {
                    result.append(charset[Int(b)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    // SHA256(nonce) -> String
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func fakeSocialLogin(name: String, email: String) {
        let user = SettingsViewController.AppUser(name: name,
                                                  email: email,
                                                  avatar: UIImage(systemName: "person.crop.circle.fill"))
        SettingsViewController.UserSession.shared.currentUser = user
        dismiss(animated: true)
    }

    // MARK: - Keyboard handling
    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(kbChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func kbChange(_ n: Notification) {
        guard let info = n.userInfo,
              let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let inset = max(0, view.bounds.maxY - end.origin.y) + 12
        scroll.contentInset.bottom = inset
        scroll.verticalScrollIndicatorInsets.bottom = inset
    }

    private func showAlert(_ t: String, _ m: String) {
        let ac = UIAlertController(title: t, message: m, preferredStyle: .alert)
        let okTitle = NSLocalizedString("settings.ok", comment: "OK button")
        ac.addAction(UIAlertAction(title: okTitle, style: .default))
        present(ac, animated: true)
    }
    
    @objc private func openRegister() {
        let vc = RegisterViewController()
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func didRegister(_ note: Notification) {
        if let email = note.userInfo?["email"] as? String {
            emailField.text = email
            passwordField.becomeFirstResponder()
        }
    }

    @objc private func didTapLanguage() {
        presentSystemLanguageHintAndOpenSettings()
    }

    private func presentSystemLanguageHintAndOpenSettings() {
        let title = L("lang.system.sheet.title")
        let message = L("lang.system.sheet.message")
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("lang.system.sheet.cancel"), style: .cancel))
        ac.addAction(UIAlertAction(title: L("lang.system.sheet.continue"), style: .default, handler: { _ in
            let urlStr = UIApplication.openSettingsURLString
            guard let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) else {
                self.showAlert(self.L("settings.language"), self.L("lang.system.unavailable"))
                return
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }))
        present(ac, animated: true)
    }
}

// MARK: - Helpers
extension UITextField {
    func setLeftPadding(_ padding: CGFloat) {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: padding, height: 1))
        leftView = v; leftViewMode = .always
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField { passwordField.becomeFirstResponder() }
        else { textField.resignFirstResponder(); didTapEmailSignIn() }
        return true
    }
}

extension Notification.Name {
    static let tasklyDidRegister = Notification.Name("Taskly.didRegister")
    static let tasklyDidLogin = Notification.Name("Taskly.didLogin")
}

final class RegisterViewController: UIViewController {
    // MARK: - Localization helper
    private func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
    private func Lf(_ key: String, _ fallback: String) -> String {
        let v = NSLocalizedString(key, comment: "")
        return (v == key) ? fallback : v
    }

    // MARK: - Apply localized texts (Register)
    private func applyLocalizedTexts_Register() {
        // Titles
        titleLabel.text = L("register.title")
        subtitleLabel.text = L("register.subtitle")

        // Placeholders
        nameField.placeholder = L("register.name.placeholder")
        emailField.placeholder = L("register.email.placeholder")
        passwordField.placeholder = L("register.password.placeholder")
        confirmField.placeholder = L("register.confirm.placeholder")

        // Buttons & footer
        signUpButton.setTitle(L("register.signup"), for: .normal)
        footerLabel.text = L("register.footer")
    }
    private let scroll = UIScrollView()
    private let content = UIStackView()

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AppLogo"))
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        iv.heightAnchor.constraint(equalToConstant: 84).isActive = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Kayıt Ol"
        lb.font = .systemFont(ofSize: 32, weight: .bold)
        lb.textAlignment = .center
        return lb
    }()

    private let subtitleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Yeni bir Taskly hesabı oluştur"
        lb.font = .preferredFont(forTextStyle: .subheadline)
        lb.textColor = .secondaryLabel
        lb.textAlignment = .center
        return lb
    }()

    private let nameField: UITextField = RegisterViewController.makeField(placeholder: "Ad Soyad")
    private let emailField: UITextField = RegisterViewController.makeField(placeholder: "E-posta", keyboard: .emailAddress)
    private let passwordField: UITextField = RegisterViewController.makeField(placeholder: "Şifre", secure: true)
    private let confirmField: UITextField = RegisterViewController.makeField(placeholder: "Şifreyi tekrar gir", secure: true)

    private let signUpButton: UIButton = {
        let bt = UIButton(type: .system)
        bt.setTitle("Kayıt Ol", for: .normal)
        bt.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        bt.backgroundColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        bt.tintColor = .white
        bt.layer.cornerRadius = 12
        bt.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return bt
    }()

    private let footerLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Zaten hesabın var mı? Giriş Yap"
        lb.font = .preferredFont(forTextStyle: .footnote)
        lb.textColor = UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
        lb.textAlignment = .center
        lb.isUserInteractionEnabled = true
        return lb
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) { overrideUserInterfaceStyle = .dark }
        view.backgroundColor = .black
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupLayout()
        // Localize all visible texts for current iOS language
        applyLocalizedTexts_Register()
        signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(backToLogin))
        footerLabel.addGestureRecognizer(tap)

        // TextField delegates & keyboard behaviors
        nameField.delegate = self
        emailField.delegate = self
        passwordField.delegate = self
        confirmField.delegate = self
        scroll.keyboardDismissMode = .interactive
        let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapDismiss)
        // Confirm alanı 'Done' yapsın
        confirmField.returnKeyType = .done
    }

    private func setupLayout() {
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scroll.addSubview(content)
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        let spacer = UIView(); spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true

        [logoView, titleLabel, subtitleLabel, spacer, nameField, emailField, passwordField, confirmField, signUpButton, footerLabel]
            .forEach { content.addArrangedSubview($0) }
    }

    @objc private func didTapSignUp() {
        guard let email = emailField.text, email.contains("@"),
              let pass = passwordField.text, pass.count >= 6,
              pass == confirmField.text else {
            showAlert("Hata", "Geçerli e‑posta ve eşleşen en az 6 karakterli şifre girin.")
            return
        }

        let displayName = nameField.text?.isEmpty == false ? nameField.text! : (email.components(separatedBy: "@").first?.capitalized ?? "Kullanıcı")

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            showAlert("Firebase Bağlı Değil", "FirebaseApp.configure() çalışmıyor. AppDelegate içinde FirebaseApp.configure() çağrısını ve GoogleService-Info.plist dosyasını kontrol et.")
            return
        }
        #endif

        #if canImport(FirebaseAuth)
        // Firebase Authentication ile gerçek kullanıcı oluşturma
        Auth.auth().createUser(withEmail: email, password: pass) { [weak self] result, error in
            guard let self = self else { return }
            if let err = error as NSError? {
                // Eğer beklenmedik şekilde kullanıcı yine de oturum açmışsa başarı say (nadir  race condition)
                if Auth.auth().currentUser != nil {
                    NotificationCenter.default.post(name: .tasklyDidRegister, object: nil, userInfo: ["email": email])
                    self.showAlert("Kayıt Başarılı", "Hesabın oluşturuldu. Lütfen giriş yap ekranından oturum aç.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.dismiss(animated: true) }
                    return
                }
                // Yaygın hata kodlarını kullanıcı dostu mesajlarla işle
                switch err.code {
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    // Zaten mevcutsa login'e yönlendir
                    NotificationCenter.default.post(name: .tasklyDidRegister, object: nil, userInfo: ["email": email])
                    self.showAlert(
                        Lf("register.error.title", "Error"),
                        Lf("register.error.emailInUse", "This email address is already in use.")
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.dismiss(animated: true) }
                case AuthErrorCode.invalidEmail.rawValue:
                    self.showAlert("Geçersiz E‑posta", "Lütfen geçerli bir e‑posta adresi gir.")
                case AuthErrorCode.weakPassword.rawValue:
                    self.showAlert("Zayıf Şifre", "Şifren en az 6 karakter olmalı.")
                case AuthErrorCode.networkError.rawValue:
                    self.showAlert("Ağ Hatası", "İnternet bağlantını kontrol edip tekrar dene.")
                default:
                    self.showAlert("Kayıt Hatası", err.localizedDescription)
                }
                return
            }

            if let user = result?.user {
                let change = user.createProfileChangeRequest()
                change.displayName = displayName
                change.commitChanges { _ in
                    // Auto-login yapma; Login ekranına dön ve e-postayı doldur
                    NotificationCenter.default.post(name: .tasklyDidRegister, object: nil, userInfo: ["email": email])
                    self.showAlert("Kayıt Başarılı", "Hesabın oluşturuldu. Lütfen giriş yap ekranından oturum aç.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.dismiss(animated: true)
                    }
                }
            } else {
                // Auto-login yapma; Login ekranına dön ve e-postayı doldur
                NotificationCenter.default.post(name: .tasklyDidRegister, object: nil, userInfo: ["email": email])
                self.showAlert("Kayıt Başarılı", "Hesabın oluşturuldu. Lütfen giriş yap ekranından oturum aç.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.dismiss(animated: true)
                }
            }
        }
        #else
        // Auto-login yapma; Login ekranına dön ve e-postayı doldur (DEMO)
        NotificationCenter.default.post(name: .tasklyDidRegister, object: nil, userInfo: ["email": email])
        showAlert("Demo Kayıt", "FirebaseAuth yüklü değil; kayıt sadece yerelde oluşturuldu. Giriş yap ekranından oturum açmayı dene.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.dismiss(animated: true)
        }
        #endif
    }

    @objc private func backToLogin() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func showAlert(_ title: String, _ message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okTitle = NSLocalizedString("settings.ok", comment: "OK button")
        ac.addAction(UIAlertAction(title: okTitle, style: .default))
        present(ac, animated: true)
    }

    private static func makeField(placeholder: String, keyboard: UIKeyboardType = .default, secure: Bool = false) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.autocapitalizationType = .none
        tf.keyboardType = keyboard
        tf.isSecureTextEntry = secure
        tf.returnKeyType = .next
        tf.clearButtonMode = .whileEditing
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.backgroundColor = .secondarySystemBackground
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        tf.setLeftPadding(14)
        return tf
    }
}

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField:
            emailField.becomeFirstResponder()
        case emailField:
            passwordField.becomeFirstResponder()
        case passwordField:
            confirmField.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
            didTapSignUp()
        }
        return true
    }
}



// MARK: - ASAuthorizationControllerDelegate
extension LoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {

        guard let appleID = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let nonce = currentNonce else {
            assertionFailure("Nonce kayıp")
            return
        }
        guard let tokenData = appleID.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            print("identityToken alınamadı.")
            showAlert(
                Lf("auth.error.title", "Sign-in Error"),
                Lf("auth.apple.missingToken", "Could not retrieve Apple identity token.")
            )
            return
        }

        #if canImport(FirebaseAuth)
        let credential = OAuthProvider.appleCredential(withIDToken: idToken,
                                                      rawNonce: nonce,
                                                      fullName: appleID.fullName)

        Auth.auth().signIn(with: credential) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                print("Firebase Apple sign-in hata:", error)
                self.showAlert("Giriş Hatası", error.localizedDescription)
                return
            }

            // İlk girişte ad/soyad geldiyse profili güncelle (opsiyonel)
            if let fn = appleID.fullName,
               (fn.givenName?.isEmpty == false || fn.familyName?.isEmpty == false) {
                let display = [fn.givenName, fn.familyName].compactMap { $0 }.joined(separator: " ")
                let change = Auth.auth().currentUser?.createProfileChangeRequest()
                change?.displayName = display
                change?.commitChanges(completion: nil)
            }

            // Firestore'a kullanıcı profili yaz (email + displayName). Email sadece ilk girişte gelebilir.
            #if canImport(FirebaseFirestore)
            if let uid = Auth.auth().currentUser?.uid {
                let db = Firestore.firestore()
                var profile: [String: Any] = [
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                // Email (Apple sadece ilk girişte sağlayabilir)
                let curEmail = Auth.auth().currentUser?.email ?? appleID.email
                if let email = curEmail { profile["email"] = email }

                // Görünen ad (sabit fallback ile her durumda yaz)
                let appleFullName: String? = {
                    if let fn = appleID.fullName, (fn.givenName?.isEmpty == false || fn.familyName?.isEmpty == false) {
                        return [fn.givenName, fn.familyName].compactMap { $0 }.joined(separator: " ")
                    }
                    return nil
                }()
                let computedName = Auth.auth().currentUser?.displayName
                    ?? appleFullName
                    ?? curEmail?.components(separatedBy: "@").first?.capitalized
                    ?? "User"
                profile["displayName"] = computedName

                db.collection("users").document(uid).setData(["profile": profile], merge: true)
            }
            #endif

            // Update in-app session (UserSession) and ensure Auth has a displayName for Apple sign-in
            DispatchQueue.main.async {
                let curEmail = Auth.auth().currentUser?.email ?? appleID.email ?? ""
                let appleFullName: String? = {
                    if let fn = appleID.fullName, (fn.givenName?.isEmpty == false || fn.familyName?.isEmpty == false) {
                        return [fn.givenName, fn.familyName].compactMap { $0 }.joined(separator: " ")
                    }
                    return nil
                }()
                let displayNow = Auth.auth().currentUser?.displayName
                    ?? appleFullName
                    ?? curEmail.components(separatedBy: "@").first?.capitalized
                    ?? "User"
                let appUser = SettingsViewController.AppUser(
                    name: displayNow,
                    email: curEmail,
                    avatar: UIImage(systemName: "person.crop.circle.fill")
                )
                SettingsViewController.UserSession.shared.currentUser = appUser

                if let u = Auth.auth().currentUser, (u.displayName == nil || u.displayName?.isEmpty == true) {
                    let change = u.createProfileChangeRequest()
                    change.displayName = displayNow
                    change.commitChanges(completion: nil)
                }

                // Notify views that rely on UserSession to refresh
                NotificationCenter.default.post(name: .init("Taskly.UserSessionDidUpdate"), object: nil)

                // Ayarlar/profil ekranları güncellesin
                NotificationCenter.default.post(name: .tasklyDidLogin, object: nil)

                // Başarılı giriş → login ekranını kapat
                self.dismiss(animated: true)
            }
        }
        #else
        showAlert("Firebase Eksik", "FirebaseAuth modülü ekli değil. Lütfen FirebaseAuth'u hedefe bağla.")
        #endif
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let ae = error as? ASAuthorizationError, ae.code == .canceled {
            return // user canceled; per HIG, do not alert
        }
        print("Apple sign-in başarısız:", error)
        showAlert(Lf("auth.error.title", "Sign-in Error"), error.localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
