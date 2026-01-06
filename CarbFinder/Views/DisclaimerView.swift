//
//  DisclaimerView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 19.11.25.
//THIS IS THE VIEW THAT DISCLAIMS INACURACIES. This is the only file for this - nobody should create a new file for this purpose
// Obligate nature of displaying this disclaimer view has been removed. It is no longer necessary, as the app is no longer a medical device. 

import SwiftUI

/// View that disclaims AI usage and potential inaccuracies
/// Rule: General Coding - Clear, simple design following Apple Design guidelines
struct DisclaimerView: View {
    
    // MARK: - Properties
    
    /// Environment for color scheme detection
    /// Rule: General Coding - Optimize for both light AND dark mode
    @Environment(\.colorScheme) private var colorScheme
    
    /// Callback when user successfully accepts disclaimer
    /// Rule: State Management - Pass callback for parent coordination
    var onAccept: () -> Void
    
    // MARK: - CHECKBOX STATE - COMMENTED OUT - START
    /// State Management: Local state for checkbox acceptance
    // @State private var hasAccepted = false
    // MARK: - CHECKBOX STATE - COMMENTED OUT - END
    
    /// State Management: Local state for language warning sheet presentation
    @State private var showLanguageWarning = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // MARK: - Feature Card with Title (Full Width, No Corners)
                        // General Coding: Beautiful full-width banner with centered title
                        ZStack(alignment: .bottomLeading) {
                            VStack(spacing: 8) {
                                Text("Informational")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                Text("Notice")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100) // Equal padding top and bottom for visual balance
                            .padding(.bottom, 100)
                            .padding(.horizontal, 40)
                            
                            // Language warning button in bottom left corner
                            Button(action: {
                                showLanguageWarning = true
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.15))
                                    )
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, 20)
                        }
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0), // #0F3D66
                                    Color(red: 0x0B/255.0, green: 0x2A/255.0, blue: 0x4A/255.0)  // #0B2A4A
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        
                        VStack(alignment: .leading, spacing: 32) {
                        
                        // MARK: - Legal Agreement Text
                        // Rule: General Coding - Pre-Use Safety Notice & User Agreement
                        VStack(alignment: .leading, spacing: 28) {
                            
                            // Warning Text
                            Text("Please read the following information carefully.")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            // Divider
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Section 1
                            VStack(alignment: .leading, spacing: 10) {
                                Text("1) AI-GENERATED DATA — MAY BE INACCURATE")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("This app provides AI-generated estimates of carbohydrate and net-carbohydrate values for foods and recipes. These outputs are produced by artificial intelligence and are not verified.\n\nAI systems may generate information that is incorrect, incomplete, misleading, or entirely fabricated. The app may misidentify foods, portions, ingredients, preparation methods, images, or recipes. Outputs may appear confident even when they are wrong.\n\nAll information provided by the app should be treated as approximate and unreliable by default.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 2
                            VStack(alignment: .leading, spacing: 10) {
                                Text("2) NO MEDICAL OR PROFESSIONAL PURPOSE")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("The app is not a medical, health, or nutrition application and is not intended for medical, dietary, or treatment purposes. It does not provide advice, recommendations, diagnoses, or instructions of any kind.\n\nYou are solely responsible for how (or whether) you use the information provided. If you require accurate, verified, or professional information, you must consult appropriate external sources or qualified professionals.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 3
                            VStack(alignment: .leading, spacing: 10) {
                                Text("3) PERSONAL USE & USER RESPONSIBILITY")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("The app is licensed for personal, informational use only by the individual who accepts this Agreement on this device.\n\nYou agree that:")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                                    .padding(.bottom, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("You are the sole authorized user of the app on this device.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                    
                                    Text("You will not allow others to rely on the app's outputs.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                    
                                    Text("You understand that all outputs may be wrong and must be independently verified before being relied upon for any purpose.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                }
                                .padding(.leading, 8)
                            }
                            
                            // Section 4
                            VStack(alignment: .leading, spacing: 10) {
                                Text("4) NO WARRANTIES")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("To the maximum extent permitted by applicable law, the app and all outputs are provided \"AS IS\" and \"AS AVAILABLE,\" without warranties of any kind, including accuracy, reliability, completeness, or fitness for any purpose.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 5
                            VStack(alignment: .leading, spacing: 10) {
                                Text("5) LIMITATION OF LIABILITY")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("To the maximum extent permitted by applicable law, the developer and related parties shall not be liable for any loss, damage, or harm arising from or related to use of, or reliance on, the app or its outputs, even if advised of the possibility.\n\nThis includes, without limitation, errors, omissions, incorrect information, or decisions made based on AI-generated content.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 6
                            VStack(alignment: .leading, spacing: 10) {
                                Text("6) AGE & ELIGIBILITY")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("You represent that you are at least 16 years old (or the age of majority in your jurisdiction) and legally able to accept these terms. If you are under the age of majority, a parent or legal guardian must consent and supervise all use.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 7
                            VStack(alignment: .leading, spacing: 10) {
                                Text("7) LOCAL RIGHTS")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("Some jurisdictions provide mandatory consumer rights that cannot be waived. These terms apply only to the extent permitted by applicable law.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            
                            // Section 8
                            VStack(alignment: .leading, spacing: 10) {
                                Text("8) ACCEPTANCE")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                Text("By tapping \"Continue,\" you confirm that you have read, understood, and accepted these terms, and that you understand the app provides unverified AI-generated information that may be incorrect.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // MARK: - CHECKBOX AGREEMENT - COMMENTED OUT - START
                        // Checkbox Agreement (in scrollable content)
                        // General Coding: Checkbox at bottom of text content
                        // HStack(alignment: .top, spacing: 16) {
                        //     // Checkbox button (always clickable)
                        //     Button(action: {
                        //         hasAccepted.toggle()
                        //         // Haptic feedback on toggle
                        //         let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        //         impactFeedback.impactOccurred()
                        //     }) {
                        //         ZStack {
                        //             RoundedRectangle(cornerRadius: 8)
                        //                 .stroke(
                        //                     hasAccepted
                        //                         ? (colorScheme == .dark ? Color.white : Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0)) // White in dark mode, blue in light mode
                        //                         : Color.secondary.opacity(0.3),
                        //                     lineWidth: 2
                        //                 )
                        //                 .frame(width: 28, height: 28)
                        //             
                        //             if hasAccepted {
                        //                 Image(systemName: "checkmark")
                        //                     .font(.system(size: 18, weight: .bold))
                        //                     .foregroundStyle(colorScheme == .dark ? Color.white : Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0)) // White in dark mode, blue in light mode
                        //             }
                        //         }
                        //     }
                        //     .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasAccepted)
                        //     .padding(.top, 2) // Align checkbox with first line of text
                        //     
                        //     // Checkbox label - Full legal confirmation
                        //     Text("I confirm that I have read and understood the Safety Notice & User Agreement above, that I am the only person allowed to use this app on this device, that I will not let others use or rely on it, that I will not use it for insulin or other treatment decisions, and that I accept all risks and the No-Warranty, Limitation-of-Liability, and Indemnity terms to the maximum extent permitted by law")
                        //         .font(.footnote)
                        //         .fontWeight(.medium)
                        //         .foregroundStyle(.primary)
                        //         .fixedSize(horizontal: false, vertical: true)
                        //         .lineSpacing(2)
                        // }
                        // .padding(.horizontal, 20)
                        // .padding(.vertical, 20)
                        // .background(
                        //     RoundedRectangle(cornerRadius: 12)
                        //         .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04)) // Higher opacity in dark mode for better visibility
                        // )
                        // .padding(.horizontal, 20)
                        // .padding(.top, 16)
                        // MARK: - CHECKBOX AGREEMENT - COMMENTED OUT - END
                        
                        // Spacer to account for sticky bottom bar
                        Spacer(minLength: 40)
                            .frame(height: 120) // Extra space for sticky continue button
                        }
                        .padding(.top, 32)
                    }
                }
                
                // MARK: - Sticky Continue Button Bar
                // General Coding: Apple Design guidelines with material background
                continueButtonBar
            }
            .ignoresSafeArea(edges: .top) // Ignore top safe area for blue banner
            .ignoresSafeArea(.keyboard, edges: .bottom) // Ignore keyboard safe area
            .sheet(isPresented: $showLanguageWarning) {
                languageWarningSheet
            }
        }
    }
    
    // MARK: - Helper Views
    
    /// Language warning sheet for non-English speakers
    /// Rule: General Coding - Multi-language warning about English proficiency requirement
    private var languageWarningSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header warning
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                        
                        Text("Language Requirement")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // All language warnings
                    VStack(alignment: .leading, spacing: 20) {
                        // English
                        LanguageWarningRow(
                            flag: "🇬🇧",
                            language: "English",
                            warning: "If your English proficiency is not good enough to truly understand the \"Safety Notice & User Agreement\" you are not allowed to use this app under any circumstance."
                        )
                        
                        // Spanish
                        LanguageWarningRow(
                            flag: "🇪🇸",
                            language: "Español (Spanish)",
                            warning: "Si su nivel de inglés no es lo suficientemente bueno como para comprender verdaderamente el \"Aviso de Seguridad y Acuerdo de Usuario\", no se le permite usar esta aplicación bajo ninguna circunstancia."
                        )
                        
                        // French
                        LanguageWarningRow(
                            flag: "🇫🇷",
                            language: "Français (French)",
                            warning: "Si votre maîtrise de l'anglais n'est pas suffisante pour comprendre véritablement l'\"Avis de Sécurité et Accord d'Utilisateur\", vous n'êtes pas autorisé à utiliser cette application en aucune circonstance."
                        )
                        
                        // German
                        LanguageWarningRow(
                            flag: "🇩🇪",
                            language: "Deutsch (German)",
                            warning: "Wenn Ihre Englischkenntnisse nicht ausreichen, um den \"Sicherheitshinweis & Benutzervereinbarung\" wirklich zu verstehen, dürfen Sie diese App unter keinen Umständen verwenden."
                        )
                        
                        // Italian
                        LanguageWarningRow(
                            flag: "🇮🇹",
                            language: "Italiano (Italian)",
                            warning: "Se la tua conoscenza dell'inglese non è abbastanza buona per comprendere veramente l'\"Avviso di Sicurezza e Accordo Utente\", non ti è permesso utilizzare questa app in nessuna circostanza."
                        )
                        
                        // Portuguese
                        LanguageWarningRow(
                            flag: "🇵🇹",
                            language: "Português (Portuguese)",
                            warning: "Se sua proficiência em inglês não for boa o suficiente para realmente entender o \"Aviso de Segurança e Acordo do Usuário\", você não tem permissão para usar este aplicativo sob nenhuma circunstância."
                        )
                        
                        // Russian
                        LanguageWarningRow(
                            flag: "🇷🇺",
                            language: "Русский (Russian)",
                            warning: "Если ваш уровень владения английским языком недостаточно хорош для того, чтобы по-настоящему понять \"Уведомление о безопасности и Пользовательское соглашение\", вам не разрешается использовать это приложение ни при каких обстоятельствах."
                        )
                        
                        // Chinese (Simplified)
                        LanguageWarningRow(
                            flag: "🇨🇳",
                            language: "中文 (Chinese Simplified)",
                            warning: "如果您的英语水平不足以真正理解\"安全须知和用户协议\"，在任何情况下都不允许您使用此应用程序。"
                        )
                        
                        // Chinese (Traditional)
                        LanguageWarningRow(
                            flag: "🇹🇼",
                            language: "中文 (Chinese Traditional)",
                            warning: "如果您的英語水平不足以真正理解\"安全須知和使用者協議\"，在任何情況下都不允許您使用此應用程式。"
                        )
                        
                        // Japanese
                        LanguageWarningRow(
                            flag: "🇯🇵",
                            language: "日本語 (Japanese)",
                            warning: "\"安全に関する注意事項とユーザー契約\"を真に理解するのに十分な英語力がない場合、いかなる状況下でもこのアプリを使用することは許可されません。"
                        )
                        
                        // Korean
                        LanguageWarningRow(
                            flag: "🇰🇷",
                            language: "한국어 (Korean)",
                            warning: "\"안전 고지 및 사용자 계약\"을 진정으로 이해할 만큼 영어 능력이 충분하지 않다면 어떠한 상황에서도 이 앱을 사용할 수 없습니다."
                        )
                        
                        // Arabic
                        LanguageWarningRow(
                            flag: "🇸🇦",
                            language: "العربية (Arabic)",
                            warning: "إذا لم تكن إجادتك للغة الإنجليزية جيدة بما يكفي لفهم \"إشعار السلامة واتفاقية المستخدم\" حقًا، فلا يُسمح لك باستخدام هذا التطبيق تحت أي ظرف من الظروف."
                        )
                        
                        // Hindi
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "हिन्दी (Hindi)",
                            warning: "यदि आपकी अंग्रेजी दक्षता \"सुरक्षा सूचना और उपयोगकर्ता समझौते\" को वास्तव में समझने के लिए पर्याप्त नहीं है, तो आपको किसी भी परिस्थिति में इस ऐप का उपयोग करने की अनुमति नहीं है।"
                        )
                        
                        // Turkish
                        LanguageWarningRow(
                            flag: "🇹🇷",
                            language: "Türkçe (Turkish)",
                            warning: "İngilizce yeterliliğiniz \"Güvenlik Bildirimi ve Kullanıcı Sözleşmesi\"ni gerçekten anlamak için yeterli değilse, hiçbir koşulda bu uygulamayı kullanmanıza izin verilmez."
                        )
                        
                        // Dutch
                        LanguageWarningRow(
                            flag: "🇳🇱",
                            language: "Nederlands (Dutch)",
                            warning: "Als uw beheersing van het Engels niet goed genoeg is om de \"Veiligheidskennisgeving en Gebruikersovereenkomst\" echt te begrijpen, mag u deze app onder geen enkele omstandigheid gebruiken."
                        )
                        
                        // Polish
                        LanguageWarningRow(
                            flag: "🇵🇱",
                            language: "Polski (Polish)",
                            warning: "Jeśli Twoja znajomość języka angielskiego nie jest wystarczająco dobra, aby naprawdę zrozumieć \"Informację o bezpieczeństwie i Umowę użytkownika\", nie możesz korzystać z tej aplikacji w żadnych okolicznościach."
                        )
                        
                        // Swedish
                        LanguageWarningRow(
                            flag: "🇸🇪",
                            language: "Svenska (Swedish)",
                            warning: "Om din engelska inte är tillräckligt bra för att verkligen förstå \"Säkerhetsmeddelande och Användaravtal\", får du inte använda denna app under några omständigheter."
                        )
                        
                        // Norwegian
                        LanguageWarningRow(
                            flag: "🇳🇴",
                            language: "Norsk (Norwegian)",
                            warning: "Hvis din engelskferdighet ikke er god nok til å virkelig forstå \"Sikkerhetsvarsel og brukeravtale\", har du ikke lov til å bruke denne appen under noen omstendigheter."
                        )
                        
                        // Danish
                        LanguageWarningRow(
                            flag: "🇩🇰",
                            language: "Dansk (Danish)",
                            warning: "Hvis din engelskkundskaber ikke er gode nok til virkelig at forstå \"Sikkerhedsmeddelelse og brugeraftale\", må du ikke bruge denne app under nogen omstændigheder."
                        )
                        
                        // Finnish
                        LanguageWarningRow(
                            flag: "🇫🇮",
                            language: "Suomi (Finnish)",
                            warning: "Jos englannin kielesi taito ei ole riittävän hyvä ymmärtämään todella \"Turvallisuusilmoitusta ja käyttäjäsopimusta\", et saa käyttää tätä sovellusta missään olosuhteissa."
                        )
                        
                        // Greek
                        LanguageWarningRow(
                            flag: "🇬🇷",
                            language: "Ελληνικά (Greek)",
                            warning: "Εάν η γνώση σας της αγγλικής γλώσσας δεν είναι αρκετά καλή για να κατανοήσετε πραγματικά την \"Ειδοποίηση Ασφαλείας και Συμφωνία Χρήστη\", δεν επιτρέπεται να χρησιμοποιήσετε αυτήν την εφαρμογή υπό οποιεσδήποτε συνθήκες."
                        )
                        
                        // Czech
                        LanguageWarningRow(
                            flag: "🇨🇿",
                            language: "Čeština (Czech)",
                            warning: "Pokud vaše znalost angličtiny není dostatečná k tomu, abyste skutečně pochopili \"Bezpečnostní upozornění a uživatelskou smlouvu\", nemáte za žádných okolností povoleno používat tuto aplikaci."
                        )
                        
                        // Romanian
                        LanguageWarningRow(
                            flag: "🇷🇴",
                            language: "Română (Romanian)",
                            warning: "Dacă cunoștințele dumneavoastră de engleză nu sunt suficient de bune pentru a înțelege cu adevărat \"Notificarea de siguranță și Acordul utilizatorului\", nu aveți voie să utilizați această aplicație în nicio circumstanță."
                        )
                        
                        // Hungarian
                        LanguageWarningRow(
                            flag: "🇭🇺",
                            language: "Magyar (Hungarian)",
                            warning: "Ha az angol nyelvtudása nem elég jó ahhoz, hogy valóban megértse a \"Biztonsági értesítést és felhasználói megállapodást\", semmilyen körülmények között nem használhatja ezt az alkalmazást."
                        )
                        
                        // Vietnamese
                        LanguageWarningRow(
                            flag: "🇻🇳",
                            language: "Tiếng Việt (Vietnamese)",
                            warning: "Nếu trình độ tiếng Anh của bạn không đủ tốt để thực sự hiểu \"Thông báo An toàn và Thỏa thuận Người dùng\", bạn không được phép sử dụng ứng dụng này trong bất kỳ trường hợp nào."
                        )
                        
                        // Thai
                        LanguageWarningRow(
                            flag: "🇹🇭",
                            language: "ไทย (Thai)",
                            warning: "หากความสามารถในภาษาอังกฤษของคุณไม่ดีพอที่จะเข้าใจ \"ประกาศความปลอดภัยและข้อตกลงผู้ใช้\" อย่างแท้จริง คุณไม่ได้รับอนุญาตให้ใช้แอปนี้ไม่ว่าในกรณีใดๆ"
                        )
                        
                        // Indonesian
                        LanguageWarningRow(
                            flag: "🇮🇩",
                            language: "Bahasa Indonesia (Indonesian)",
                            warning: "Jika kemampuan bahasa Inggris Anda tidak cukup baik untuk benar-benar memahami \"Pemberitahuan Keamanan & Perjanjian Pengguna\", Anda tidak diizinkan menggunakan aplikasi ini dalam keadaan apa pun."
                        )
                        
                        // Malay
                        LanguageWarningRow(
                            flag: "🇲🇾",
                            language: "Bahasa Melayu (Malay)",
                            warning: "Jika kemahiran bahasa Inggeris anda tidak cukup baik untuk benar-benar memahami \"Notis Keselamatan & Perjanjian Pengguna\", anda tidak dibenarkan menggunakan aplikasi ini dalam apa jua keadaan."
                        )
                        
                        // Hebrew
                        LanguageWarningRow(
                            flag: "🇮🇱",
                            language: "עברית (Hebrew)",
                            warning: "אם רמת האנגלית שלך אינה מספיק טובה כדי להבין באמת את \"הודעת הבטיחות והסכם המשתמש\", אינך רשאי להשתמש באפליקציה זו בשום נסיבות."
                        )
                        
                        // Ukrainian
                        LanguageWarningRow(
                            flag: "🇺🇦",
                            language: "Українська (Ukrainian)",
                            warning: "Якщо ваше володіння англійською мовою недостатньо добре, щоб справді зрозуміти \"Повідомлення про безпеку та Угоду користувача\", вам не дозволяється використовувати цей додаток за жодних обставин."
                        )
                        
                        // Bengali
                        LanguageWarningRow(
                            flag: "🇧🇩",
                            language: "বাংলা (Bengali)",
                            warning: "যদি আপনার ইংরেজি দক্ষতা \"নিরাপত্তা বিজ্ঞপ্তি এবং ব্যবহারকারী চুক্তি\" সত্যিকার অর্থে বোঝার জন্য যথেষ্ট ভাল না হয়, তবে আপনাকে কোনো পরিস্থিতিতে এই অ্যাপটি ব্যবহার করার অনুমতি নেই।"
                        )
                        
                        // Swahili
                        LanguageWarningRow(
                            flag: "🇰🇪",
                            language: "Kiswahili (Swahili)",
                            warning: "Ikiwa ujuzi wako wa Kiingereza si mzuri vya kutosha kuelewa kweli \"Tangazo la Usalama na Mkataba wa Mtumiaji\", huruhusiwi kutumia programu hii chini ya hali yoyote."
                        )
                        
                        // Filipino
                        LanguageWarningRow(
                            flag: "🇵🇭",
                            language: "Filipino (Tagalog)",
                            warning: "Kung ang iyong kadalubhasaan sa Ingles ay hindi sapat upang tunay na maunawaan ang \"Paunawa sa Kaligtasan at Kasunduan ng Gumagamit\", hindi ka pinapayagang gumamit ng app na ito sa anumang kalagayan."
                        )
                        
                        // Urdu
                        LanguageWarningRow(
                            flag: "🇵🇰",
                            language: "اردو (Urdu)",
                            warning: "اگر آپ کی انگریزی کی مہارت \"حفاظتی نوٹس اور صارف کے معاہدے\" کو واقعی سمجھنے کے لیے کافی اچھی نہیں ہے، تو آپ کو کسی بھی صورت میں اس ایپ کو استعمال کرنے کی اجازت نہیں ہے۔"
                        )
                        
                        // Persian (Farsi)
                        LanguageWarningRow(
                            flag: "🇮🇷",
                            language: "فارسی (Persian/Farsi)",
                            warning: "اگر مهارت شما در زبان انگلیسی به اندازه کافی خوب نیست تا \"اطلاعیه ایمنی و توافقنامه کاربر\" را واقعاً درک کنید، در هیچ شرایطی مجاز به استفاده از این برنامه نیستید."
                        )
                        
                        // Afrikaans
                        LanguageWarningRow(
                            flag: "🇿🇦",
                            language: "Afrikaans",
                            warning: "As jou Engelse vaardigheid nie goed genoeg is om die \"Veiligheidskennis en Gebruikersooreenkoms\" werklik te verstaan nie, mag jy hierdie app onder geen omstandighede gebruik nie."
                        )
                        
                        // Amharic
                        LanguageWarningRow(
                            flag: "🇪🇹",
                            language: "አማርኛ (Amharic)",
                            warning: "የእንግሊዝኛ ብቃትዎ \"የደህንነት ማስታወቂያ እና የተጠቃሚ ስምምነት\" በእውነት ለመረዳት በቂ ካልሆነ፣ ይህን መተግበሪያ በማንኛውም ሁኔታ ለመጠቀም አይፈቀድልዎትም።"
                        )
                        
                        // Azerbaijani
                        LanguageWarningRow(
                            flag: "🇦🇿",
                            language: "Azərbaycan (Azerbaijani)",
                            warning: "Əgər ingilis dilini bilməyiniz \"Təhlükəsizlik Bildirişi və İstifadəçi Müqaviləsini\" həqiqətən başa düşmək üçün kifayət deyilsə, heç bir halda bu tətbiqdən istifadə etməyə icazəniz yoxdur."
                        )
                        
                        // Belarusian
                        LanguageWarningRow(
                            flag: "🇧🇾",
                            language: "Беларуская (Belarusian)",
                            warning: "Калі вашага ўзроўню англійскай мовы недастаткова, каб сапраўды зразумець \"Апавяшчэнне аб бяспецы і Карыстальніцкую згоду\", вам не дазваляецца выкарыстоўваць гэту праграму ні пры якіх абставінах."
                        )
                        
                        // Bulgarian
                        LanguageWarningRow(
                            flag: "🇧🇬",
                            language: "Български (Bulgarian)",
                            warning: "Ако вашето владеене на английски не е достатъчно добро, за да разберете наистина \"Уведомлението за безопасност и Потребителското споразумение\", не ви е позволено да използвате това приложение при никакви обстоятелства."
                        )
                        
                        // Catalan
                        LanguageWarningRow(
                            flag: "🏴",
                            language: "Català (Catalan)",
                            warning: "Si el vostre domini de l'anglès no és prou bo per comprendre realment l'\"Avís de Seguretat i Acord d'Usuari\", no se us permet utilitzar aquesta aplicació sota cap circumstància."
                        )
                        
                        // Croatian
                        LanguageWarningRow(
                            flag: "🇭🇷",
                            language: "Hrvatski (Croatian)",
                            warning: "Ako vaše znanje engleskog nije dovoljno dobro da stvarno razumijete \"Obavijest o sigurnosti i Korisnički sporazum\", nije vam dopušteno koristiti ovu aplikaciju ni pod kakvim okolnostima."
                        )
                        
                        // Estonian
                        LanguageWarningRow(
                            flag: "🇪🇪",
                            language: "Eesti (Estonian)",
                            warning: "Kui teie inglise keele oskus ei ole piisavalt hea, et tõeliselt mõista \"Ohutusteadet ja Kasutajalepingut\", ei tohi te seda rakendust mitte mingil juhul kasutada."
                        )
                        
                        // Georgian
                        LanguageWarningRow(
                            flag: "🇬🇪",
                            language: "ქართული (Georgian)",
                            warning: "თუ თქვენი ინგლისური ენის ცოდნა არ არის საკმარისად კარგი, რომ ნამდვილად გაიგოთ \"უსაფრთხოების შეტყობინება და მომხმარებლის შეთანხმება\", არ გაქვთ უფლება გამოიყენოთ ეს აპლიკაცია არანაირ პირობებში."
                        )
                        
                        // Gujarati
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "ગુજરાતી (Gujarati)",
                            warning: "જો તમારી અંગ્રેજી નિપુણતા \"સલામતી નોટિસ અને વપરાશકર્તા કરાર\" ને ખરેખર સમજવા માટે પૂરતી સારી નથી, તો તમને કોઈપણ સંજોગોમાં આ એપનો ઉપયોગ કરવાની મંજૂરી નથી."
                        )
                        
                        // Hausa
                        LanguageWarningRow(
                            flag: "🇳🇬",
                            language: "Hausa",
                            warning: "Idan ƙwarewar Turanci ba ta isa ba don fahimtar \"Sanarwar Aminci da Yarjejeniyar Mai amfani\" da gaske, ba a ba ku izinin amfani da wannan app a kowane hali."
                        )
                        
                        // Icelandic
                        LanguageWarningRow(
                            flag: "🇮🇸",
                            language: "Íslenska (Icelandic)",
                            warning: "Ef enskukunnátta þín er ekki nógu góð til að skilja virkilega \"Öryggistilkynningu og Notendaásamning\", er þér ekki heimilt að nota þetta forrit við neinar aðstæður."
                        )
                        
                        // Igbo
                        LanguageWarningRow(
                            flag: "🇳🇬",
                            language: "Igbo",
                            warning: "Ọ bụrụ na amamihe gị n'asụsụ Bekee ezughị oke ịghọta \"Ọkwa Nchekwa na Nkwekọrịta Onye Ọrụ\" n'ezie, anaghị enye gị ikike iji ngwa a n'ọnọdụ ọ bụla."
                        )
                        
                        // Kannada
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "ಕನ್ನಡ (Kannada)",
                            warning: "\"ಸುರಕ್ಷತಾ ಸೂಚನೆ ಮತ್ತು ಬಳಕೆದಾರರ ಒಪ್ಪಂದ\" ಅನ್ನು ನಿಜವಾಗಿ ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲು ನಿಮ್ಮ ಇಂಗ್ಲಿಷ್ ಪ್ರಾವೀಣ್ಯತೆ ಸಾಕಷ್ಟು ಉತ್ತಮವಾಗಿಲ್ಲದಿದ್ದರೆ, ಯಾವುದೇ ಸಂದರ್ಭದಲ್ಲಿ ಈ ಅಪ್ಲಿಕೇಶನ್ ಅನ್ನು ಬಳಸಲು ನಿಮಗೆ ಅನುಮತಿ ಇಲ್ಲ."
                        )
                        
                        // Kazakh
                        LanguageWarningRow(
                            flag: "🇰🇿",
                            language: "Қазақ (Kazakh)",
                            warning: "Егер сіздің ағылшын тіліндегі білім деңгейіңіз \"Қауіпсіздік туралы хабарлама және Пайдаланушы келісімін\" шынымен түсіну үшін жеткіліксіз болса, сіз бұл қолданбаны ешқандай жағдайда пайдалануға рұқсат етілмейсіз."
                        )
                        
                        // Khmer
                        LanguageWarningRow(
                            flag: "🇰🇭",
                            language: "ខ្មែរ (Khmer)",
                            warning: "ប្រសិនបើជំនាញភាសាអង់គ្លេសរបស់អ្នកមិនល្អគ្រប់គ្រាន់ដើម្បីយល់ពីការពិតនៃ \"ការជូនដំណឹងសុវត្ថិភាព និងកិច្ចព្រមព្រៀងអ្នកប្រើប្រាស់\" អ្នកមិនត្រូវបានអនុញ្ញាតឱ្យប្រើកម្មវិធីនេះក្រោមកាលៈទេសៈណាមួយឡើយ។"
                        )
                        
                        // Lao
                        LanguageWarningRow(
                            flag: "🇱🇦",
                            language: "ລາວ (Lao)",
                            warning: "ຖ້າຄວາມຊໍານິຊໍານານພາສາອັງກິດຂອງທ່ານບໍ່ດີພໍທີ່ຈະເຂົ້າໃຈຢ່າງແທ້ຈິງກ່ຽວກັບ \"ແຈ້ງການຄວາມປອດໄພ ແລະ ຂໍ້ຕົກລົງຜູ້ໃຊ້\", ທ່ານບໍ່ໄດ້ຮັບອະນຸຍາດໃຫ້ໃຊ້ແອັບນີ້ພາຍໃຕ້ສະຖານະການໃດກໍຕາມ."
                        )
                        
                        // Latvian
                        LanguageWarningRow(
                            flag: "🇱🇻",
                            language: "Latviešu (Latvian)",
                            warning: "Ja jūsu angļu valodas prasmes nav pietiekamas, lai patiesi saprastu \"Drošības paziņojumu un lietotāja līgumu\", jums nav atļauts izmantot šo lietotni nekādos apstākļos."
                        )
                        
                        // Lithuanian
                        LanguageWarningRow(
                            flag: "🇱🇹",
                            language: "Lietuvių (Lithuanian)",
                            warning: "Jei jūsų anglų kalbos įgūdžiai nėra pakankamai geri, kad tikrai suprastumėte \"Saugos pranešimą ir Naudotojo sutartį\", jums neleidžiama naudoti šios programos jokiomis aplinkybėmis."
                        )
                        
                        // Macedonian
                        LanguageWarningRow(
                            flag: "🇲🇰",
                            language: "Македонски (Macedonian)",
                            warning: "Ако вашето познавање на англискиот јазик не е доволно добро за да го разберете навистина \"Известувањето за безбедност и Договорот за корисник\", не ви е дозволено да ја користите оваа апликација под никакви околности."
                        )
                        
                        // Malayalam
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "മലയാളം (Malayalam)",
                            warning: "\"സുരക്ഷാ അറിയിപ്പും ഉപയോക്തൃ കരാറും\" യഥാർത്ഥത്തിൽ മനസ്സിലാക്കാൻ നിങ്ങളുടെ ഇംഗ്ലീഷ് പ്രാവീണ്യം മതിയാകുന്നില്ലെങ്കിൽ, ഒരു സാഹചര്യത്തിലും ഈ ആപ്പ് ഉപയോഗിക്കാൻ നിങ്ങൾക്ക് അനുവാദമില്ല."
                        )
                        
                        // Marathi
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "मराठी (Marathi)",
                            warning: "जर तुमची इंग्रजी प्रवीणता \"सुरक्षा सूचना आणि वापरकर्ता करार\" खरोखर समजून घेण्यासाठी पुरेशी चांगली नसेल, तर तुम्हाला कोणत्याही परिस्थितीत हे अॅप वापरण्याची परवानगी नाही."
                        )
                        
                        // Mongolian
                        LanguageWarningRow(
                            flag: "🇲🇳",
                            language: "Монгол (Mongolian)",
                            warning: "Хэрэв таны англи хэлний мэдлэг \"Аюулгүй байдлын мэдэгдэл болон Хэрэглэгчийн гэрээ\"-г үнэхээр ойлгоход хангалттай сайн биш бол та ямар ч тохиолдолд энэ аппликэйшныг ашиглахыг зөвшөөрөхгүй."
                        )
                        
                        // Nepali
                        LanguageWarningRow(
                            flag: "🇳🇵",
                            language: "नेपाली (Nepali)",
                            warning: "यदि तपाईंको अंग्रेजी प्रवीणता \"सुरक्षा सूचना र प्रयोगकर्ता सम्झौता\" वास्तवमा बुझ्नको लागि पर्याप्त राम्रो छैन भने, तपाईंलाई कुनै पनि अवस्थामा यो एप प्रयोग गर्न अनुमति छैन।"
                        )
                        
                        // Punjabi
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "ਪੰਜਾਬੀ (Punjabi)",
                            warning: "ਜੇਕਰ ਤੁਹਾਡੀ ਅੰਗਰੇਜ਼ੀ ਦੀ ਮੁਹਾਰਤ \"ਸੁਰੱਖਿਆ ਨੋਟਿਸ ਅਤੇ ਉਪਭੋਗਤਾ ਸਮਝੌਤੇ\" ਨੂੰ ਸੱਚਮੁੱਚ ਸਮਝਣ ਲਈ ਕਾਫ਼ੀ ਵਧੀਆ ਨਹੀਂ ਹੈ, ਤਾਂ ਤੁਹਾਨੂੰ ਕਿਸੇ ਵੀ ਸਥਿਤੀ ਵਿੱਚ ਇਸ ਐਪ ਨੂੰ ਵਰਤਣ ਦੀ ਇਜਾਜ਼ਤ ਨਹੀਂ ਹੈ।"
                        )
                        
                        // Serbian
                        LanguageWarningRow(
                            flag: "🇷🇸",
                            language: "Српски (Serbian)",
                            warning: "Ако ваше знање енглеског језика није довољно добро да заиста разумете \"Обавештење о безбедности и Корисничку дозволу\", није вам дозвољено да користите ову апликацију ни под каквим околностима."
                        )
                        
                        // Sinhala
                        LanguageWarningRow(
                            flag: "🇱🇰",
                            language: "සිංහල (Sinhala)",
                            warning: "ඔබගේ ඉංග්‍රීසි ප්‍රවීණතාවය \"ආරක්ෂණ දැනුම්දීම සහ පරිශීලක ගිවිසුම\" සැබවින්ම තේරුම් ගැනීමට ප්‍රමාණවත් තරම් හොඳ නොවේ නම්, ඔබට කිසිදු අවස්ථාවක දී මෙම යෙදුම භාවිතා කිරීමට අවසර නැත."
                        )
                        
                        // Slovak
                        LanguageWarningRow(
                            flag: "🇸🇰",
                            language: "Slovenčina (Slovak)",
                            warning: "Ak vaša znalosť angličtiny nie je dostatočná na to, aby ste skutočne pochopili \"Bezpečnostné upozornenie a Používateľskú dohodu\", nie je vám za žiadnych okolností povolené používať túto aplikáciu."
                        )
                        
                        // Slovenian
                        LanguageWarningRow(
                            flag: "🇸🇮",
                            language: "Slovenščina (Slovenian)",
                            warning: "Če vaše znanje angleščine ni dovolj dobro, da bi resnično razumeli \"Varnostno obvestilo in Uporabniško pogodbo\", vam pod nobenim pogojem ni dovoljeno uporabljati te aplikacije."
                        )
                        
                        // Somali
                        LanguageWarningRow(
                            flag: "🇸🇴",
                            language: "Soomaali (Somali)",
                            warning: "Haddii aqoontaada Ingiriisiga aysan ku filnayn inaad si dhab ah u fahamto \"Ogeysiiska Badbaadada iyo Heshiiska Isticmaalaha\", laguma ogola inaad isticmaasho app-kan xaalad kasta oo jirta."
                        )
                        
                        // Tamil
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "தமிழ் (Tamil)",
                            warning: "\"பாதுகாப்பு அறிவிப்பு மற்றும் பயனர் ஒப்பந்தத்தை\" உண்மையாகப் புரிந்துகொள்ள உங்கள் ஆங்கிலத் திறன் போதுமானதாக இல்லை என்றால், எந்த சூழ்நிலையிலும் இந்த செயலியைப் பயன்படுத்த உங்களுக்கு அனுமதி இல்லை."
                        )
                        
                        // Telugu
                        LanguageWarningRow(
                            flag: "🇮🇳",
                            language: "తెలుగు (Telugu)",
                            warning: "\"భద్రతా నోటీసు మరియు వినియోగదారు ఒప్పందాన్ని\" నిజంగా అర్థం చేసుకోవడానికి మీ ఆంగ్ల ప్రావీణ్యత తగినంతగా లేకపోతే, ఏ పరిస్థితుల్లోనూ మీరు ఈ యాప్‌ను ఉపయోగించడానికి అనుమతించబడరు."
                        )
                        
                        // Uzbek
                        LanguageWarningRow(
                            flag: "🇺🇿",
                            language: "O'zbek (Uzbek)",
                            warning: "Agar sizning ingliz tili bilimingiz \"Xavfsizlik haqida ogohlantirish va Foydalanuvchi shartnomasi\"ni haqiqatan ham tushunish uchun yetarli darajada yaxshi bo'lmasa, hech qanday holatda ushbu ilovadan foydalanishga ruxsat berilmaydi."
                        )
                        
                        // Yoruba
                        LanguageWarningRow(
                            flag: "🇳🇬",
                            language: "Yorùbá (Yoruba)",
                            warning: "Ti imọ rẹ nipa ede Gẹẹsi ko ba dara to lati loye \"Ikilọ Aabo ati Adehun Olumulo\" ni otitọ, ko gba ọ laaye lati lo app yii labẹ eyikeyi ipo."
                        )
                        
                        // Zulu
                        LanguageWarningRow(
                            flag: "🇿🇦",
                            language: "isiZulu (Zulu)",
                            warning: "Uma ulwazi lwakho lwesiNgisi alulungele ngokwanele ukuqonda ngempela \"Isaziso Sokuphepha Nesivumelwano Somsebenzisi\", awuvunyelwe ukusebenzisa lolu hlelo lokusebenza kunoma yisiphi isimo."
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Language Warning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showLanguageWarning = false
                    }
                }
            }
        }
    }
    
    /// Sticky continue button bar at bottom
    /// Rule: General Coding - Apple Design with material background
    private var continueButtonBar: some View {
        VStack(spacing: 14) {
            // MARK: - CHECKBOX WARNING TEXT - COMMENTED OUT - START
            // Warning text when checkbox not checked
            // if !hasAccepted {
            //     Text("Read the full text and confirm understanding before continuing")
            //         .font(.caption)
            //         .foregroundStyle(.secondary)
            //         .multilineTextAlignment(.center)
            //         .fixedSize(horizontal: false, vertical: true)
            //         .padding(.horizontal, 20)
            //         .transition(.opacity.combined(with: .scale(scale: 0.95).combined(with: .move(edge: .top))))
            // }
            // MARK: - CHECKBOX WARNING TEXT - COMMENTED OUT - END
            
            // Understood button (always enabled now)
            Button(action: {
                print("[DisclaimerView] Understood tapped - user acknowledged disclaimer")
                // Rule: General Coding - Call callback to notify parent
                onAccept()
            }) {
                HStack(spacing: 10) {
                    Text("Understood")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // MARK: - CHECKBOX ARROW ICON - COMMENTED OUT - START
                    // if hasAccepted {
                    //     Image(systemName: "arrow.right")
                    //         .font(.headline)
                    //         .transition(.scale.combined(with: .opacity))
                    // }
                    // MARK: - CHECKBOX ARROW ICON - COMMENTED OUT - END
                    
                    // Always show arrow icon now
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        // MARK: - CHECKBOX BUTTON COLOR - COMMENTED OUT - START
                        // .fill(
                        //     hasAccepted
                        //         ? Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0) // #0F3D66 - Solid blue matching header
                        //         : Color.gray.opacity(0.6)
                        // )
                        // .shadow(
                        //     color: hasAccepted
                        //         ? Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0).opacity(0.3)
                        //         : Color.clear,
                        //     radius: 8,
                        //     y: 4
                        // )
                        // MARK: - CHECKBOX BUTTON COLOR - COMMENTED OUT - END
                        // Always use active blue color now
                        .fill(Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0)) // #0F3D66 - Solid blue matching header
                        .shadow(
                            color: Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0).opacity(0.3),
                            radius: 8,
                            y: 4
                        )
                )
            }
            // MARK: - CHECKBOX BUTTON DISABLED STATE - COMMENTED OUT - START
            // .disabled(!hasAccepted)
            // // Visual feedback: Animation for button state
            // .animation(.spring(response: 0.4, dampingFraction: 0.7), value: hasAccepted)
            // MARK: - CHECKBOX BUTTON DISABLED STATE - COMMENTED OUT - END
            // Button is always enabled now
            .padding(.horizontal, 20)
        }
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background(
            .regularMaterial
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: -6)
        .ignoresSafeArea(edges: .bottom) // Box doesn't respect safe area
    }
}

// MARK: - Preview

#Preview {
    DisclaimerView(onAccept: {
        print("Preview: Disclaimer accepted")
    })
}
// MARK: - Helper Structures

/// Row view for displaying language warning
/// Rule: General Coding - Reusable component for language warnings
private struct LanguageWarningRow: View {
    let flag: String
    let language: String
    let warning: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(flag)
                    .font(.title2)
                
                Text(language)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(warning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

