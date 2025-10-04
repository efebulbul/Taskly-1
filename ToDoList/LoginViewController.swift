import UIKit
import AuthenticationServices  // Sign in with Apple (opsiyonel)
import WebKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class LoginViewController: UIViewController {

    // MARK: - UI
    private let scroll = UIScrollView()
    private let content = UIStackView()

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AppLogo")) // yoksa SF Symbol kullan
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
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
        bt.backgroundColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
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

    private let appleButton: UIButton = {
        let bt = UIButton(type: .system)
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = .label
        cfg.baseForegroundColor = .systemBackground
        cfg.cornerStyle = .large
        cfg.title = "Apple ile devam et"
        cfg.image = UIImage(systemName: "apple.logo")
        cfg.imagePadding = 8
        bt.configuration = cfg
        bt.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return bt
    }()

    private let googleButton: UIButton = {
        let bt = UIButton(type: .system)
        var cfg = UIButton.Configuration.tinted()
        cfg.baseBackgroundColor = .systemBackground
        cfg.baseForegroundColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
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
        lb.textColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
        lb.textAlignment = .center
        lb.isUserInteractionEnabled = true
        return lb
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupLayout()
        signInButton.addTarget(self, action: #selector(didTapEmailSignIn), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(didTapApple), for: .touchUpInside)
        googleButton.addTarget(self, action: #selector(didTapGoogle), for: .touchUpInside)

        // Klavye için
        emailField.delegate = self
        passwordField.delegate = self
        registerForKeyboardNotifications()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(openRegister))
        registerLabel.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(didRegister(_:)), name: .tasklyDidRegister, object: nil)
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
            showAlert("Hata", "Geçerli e-posta ve en az 6 karakterli şifre gir.")
            return
        }

        #if canImport(FirebaseAuth)
        // Gerçek giriş: Firebase Authentication
        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] result, error in
            guard let self = self else { return }
            if let err = error as NSError? {
                // Kullanıcı bulunamadı veya şifre hatalı senaryolarını ayrıştır
                if err.code == AuthErrorCode.userNotFound.rawValue {
                    let ac = UIAlertController(title: "Hesap Bulunamadı", message: "Bu e‑posta ile hesap yok. Kayıt olmak ister misin?", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
                    ac.addAction(UIAlertAction(title: "Kayıt Ol", style: .default, handler: { _ in
                        self.openRegister()
                    }))
                    self.present(ac, animated: true)
                } else if err.code == AuthErrorCode.wrongPassword.rawValue {
                    self.showAlert("Hatalı Şifre", "Şifreni kontrol et ve tekrar dene.")
                } else {
                    self.showAlert("Giriş Hatası", err.localizedDescription)
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
        // Basit demo: gerçek Apple Sign In entegrasyonu için Capability + ASAuthorizationController gerekir.
        if #available(iOS 13.0, *) {
            // Burada gerçek Apple flow’u çalıştırabilirsin.
            fakeSocialLogin(name: "Apple Kullanıcısı", email: "appleuser@taskly.app")
        } else {
            showAlert("Desteklenmiyor", "Bu özellik iOS 13 ve sonrası için geçerlidir.")
        }
    }

    @objc private func didTapGoogle() {
        // Gerçek Google Sign-In için GoogleSignIn SDK kurulmalı (URL scheme + client ID).
        fakeSocialLogin(name: "Google Kullanıcısı", email: "googleuser@taskly.app")
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
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(ac, animated: true)
    }
    
    @objc private func openRegister() {
        let vc = RegisterViewController()
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }

    @objc private func didRegister(_ note: Notification) {
        if let email = note.userInfo?["email"] as? String {
            emailField.text = email
            passwordField.becomeFirstResponder()
        }
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
}

final class RegisterViewController: UIViewController {
    private let scroll = UIScrollView()
    private let content = UIStackView()

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AppLogo"))
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
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
        bt.backgroundColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
        bt.tintColor = .white
        bt.layer.cornerRadius = 12
        bt.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return bt
    }()

    private let footerLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Zaten hesabın var mı? Giriş Yap"
        lb.font = .preferredFont(forTextStyle: .footnote)
        lb.textColor = UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)
        lb.textAlignment = .center
        lb.isUserInteractionEnabled = true
        return lb
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupLayout()
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
                    self.showAlert("Zaten Kayıtlı", "Bu e‑posta ile bir hesap zaten var. Giriş yap ekranına dönüyoruz.")
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
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
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

