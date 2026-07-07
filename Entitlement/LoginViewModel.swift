//
//  LoginViewModel.swift
//  Entitlement
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API_NoCertificate
import StosSign_Auth

class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var isLoginInProgress = false
    @Published var logs = ""
    
    private var verificationCodeHandler: ((String?) -> Void)?
    
    func submitVerficationCode() {
        if let verificationCodeHandler {
            verificationCodeHandler(verificationCode)
        }
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        await MainActor.run {
            logs = ""
            isLoginInProgress = true
        }
        
        func logging(text: String) {
            Task { await MainActor.run {
                self.logs.append("\(text)\n")
            }}
        }
        
        AnisetteDataHelper.shared.loggingFunc = logging

        defer {
            Task{ await MainActor.run {
                self.appleID = ""
                self.password = ""
                needVerificationCode = false
                verificationCode = ""
                isLoginInProgress = false
            }}
        }
        
        let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
        
        let (account, session) = try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [self] (completionHandler) in
            verificationCodeHandler = completionHandler
            Task{ await MainActor.run {
                needVerificationCode = true
            }}
        }
        logging(text: "Successfully signed in")
        
        DataManager.shared.model.account = account
        DataManager.shared.model.session = session
        Keychain.shared.appleIDEmailAddress = self.appleID
        Keychain.shared.appleIDPassword = self.password
        
        let team = try await fetchTeam(for: account, session: session)
        logging(text: "Successfully fetched team")
        DataManager.shared.model.team = team
        
        Task{ await MainActor.run {
            DataManager.shared.model.isLogin = true
        }}
        
        return true
    }
    
    func fetchTeam(for account: Account, session: AppleAPISession) async throws -> Team
    {

        let fetchedTeams = try await AppleAPI.shared.fetchTeamsForAccount(account: account, session: session)
        guard !fetchedTeams.isEmpty, let team = fetchedTeams.first else {
            throw "Unable to Fetch Team!"
        }
        
        return team
    }
}
