//
//  ProfileView.swift
//  Leomard
//
//  Created by Konrad Figura on 02/07/2023.
//

import Foundation
import SwiftUI

struct ProfileView: View {
    let commentService: CommentService
    let contentView: ContentView
    let person: Person
    @Binding var myself: MyUserInfo?
    
    @State var personDetails: GetPersonDetailsResponse? = nil
    
    @State var postService: PostService? = nil
    @State var personService: PersonService? = nil
    @State var browseOptions: [Option] = [
        .init(id: 0, title: "Comments", imageName: "message"),
        .init(id: 1, title: "Posts", imageName: "doc.plaintext"),
    ]
    @State var selectedBrowseOption: Option = Option(id: 0, title: "Comments", imageName: "message")
    @State var selectedSort: SortType = UserPreferences.getInstance.profileSortMethod
    
    @State var page: Int = 1
    
    @State fileprivate var selectededSession: SessionPickerOption = SessionPickerOption(title: "", sessionInfo: nil)
    @State fileprivate var sessions: [SessionPickerOption] = []
    @State fileprivate var addNewOption: SessionPickerOption = SessionPickerOption(title: "Add New", sessionInfo: nil)
    
    @State var sessionChangeFail: Bool = false
    
    @State var showLogoutAlert: Bool = false
    
    var body: some View {
        toolbar
            .frame(
                minWidth: 0,
                maxWidth: .infinity
            )
            .padding(.leading)
            .padding(.trailing)
        profileContent
            .cornerRadius(8)
            .task {
                if person == myself?.localUserView.person {
                    browseOptions.append(Option(id: 2, title: "Saved", imageName: "star"))
                }
                
                let requestHandler = RequestHandler()
                self.postService = PostService(requestHandler: requestHandler)
                self.personService = PersonService(requestHandler: requestHandler)
                loadPersonDetails()
            }
        Spacer()
    }
    
    // MARK: -
    
    @ViewBuilder
    private var profileContent: some View {
        VStack {
            GeometryReader { proxy in
                HStack {
                    profileContentList(
                        personDetails,
                        sidebarVisible: proxy.size.width < 1000)
                    .frame(
                        minWidth: 0,
                        maxWidth: 600,
                        maxHeight: .infinity,
                        alignment: .center
                    )
                    
                    profileSidebar(visible: proxy.size.width > 1000)
                        .frame(
                            minWidth: 0,
                            maxWidth: 400,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
            .alert("Error changing profile", isPresented: $sessionChangeFail, actions: {
                Button("OK", role: .cancel) {}
            }, message: { Text("Failed to change the session") })
        }
    }
    
    @ViewBuilder
    private func profileContentList(_ personDetails: GetPersonDetailsResponse?, sidebarVisible: Bool) -> some View {
        List {
            if let personDetails {
                /// Why are we showing another profile sidebar here?
                if sidebarVisible {
                    VStack {
                        ProfileSidebarUIView(personView: personDetails.personView, myself: $myself, personService: personService!)
                    }
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity
                    )
                    .cornerRadius(8)
                    .padding(.bottom, 15)
                }
                switch selectedBrowseOption.id {
                case 0:
                    commentsList(personDetails)
                default:
                    postsList(personDetails)
                }
            }
        }
    }
    
    @ViewBuilder
    private func commentsList(_ personDetails: GetPersonDetailsResponse) -> some View {
        if personDetails.comments == [] {
            Text("No comments found!")
                .italic()
                .foregroundColor(.secondary)
        } else {
            ForEach(personDetails.comments, id: \.self) { commentView in
                VStack {
                    CommentUIView(commentView: commentView, indentLevel: 1, commentService: commentService, myself: $myself, post: commentView.post, contentView: contentView, profileViewMode: true)
                        .onAppear {
                            if commentView == personDetails.comments.last {
                                self.loadPersonDetails()
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.trailing, 15)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .onTapGesture {
                    self.loadPostFromComment(commentView: commentView)
                }
                Spacer()
                    .frame(height: 0)
            }
        }
    }
    
    @ViewBuilder
    private func postsList(_ personDetails: GetPersonDetailsResponse) -> some View {
        if personDetails.posts == [] {
            Text("No posts found!")
                .italic()
                .foregroundColor(.secondary)
        } else {
            ForEach(personDetails.posts, id: \.self) { postView in
                PostUIView(postView: postView, shortBody: true, postService: self.postService!, myself: $myself, contentView: contentView)
                    .onAppear {
                        if postView == personDetails.posts.last {
                            self.loadPersonDetails()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
                    .frame(height: 0)
            }
        }
    }
    
    @ViewBuilder
    private func profileSidebar(visible: Bool) -> some View {
        if visible {
            List {
                VStack {
                    if personDetails != nil {
                        ProfileSidebarUIView(personView: personDetails!.personView, myself: $myself, personService: personService!)
                    }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity
                )
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 10) {
            dismissButton
            Spacer()
            profileToolbarItems
            Spacer()
            sessionPicker
        }
    }
    
    @ViewBuilder
    private var dismissButton: some View {
        if person != myself?.localUserView.person {
            Button("Dismiss", action: contentView.dismissProfileView)
                .buttonStyle(.link)
        }
    }
    
    @ViewBuilder
    private var profileToolbarItems: some View {
        HStack {
            HStack {
                Image(systemName: selectedBrowseOption.imageName)
                    .padding(.trailing, 0)
                Picker("", selection: $selectedBrowseOption) {
                    ForEach(browseOptions, id: \.self) { method in
                        Text(method.title)
                    }
                }
                .frame(maxWidth: 120)
                .padding(.leading, -10)
                .onChange(of: selectedBrowseOption) { value in
                    self.reloadFeed()
                }
                Image(systemName: selectedSort.image)
                    .padding(.trailing, 0)
                Picker("", selection: $selectedSort) {
                    ForEach(UserPreferences.getInstance.profileSortTypes, id: \.self) { method in
                        Text(String(describing: method))
                    }
                }
                .frame(maxWidth: 80)
                .padding(.leading, -10)
                .onChange(of: selectedSort) { value in
                    self.reloadFeed()
                }
            }
            Button(action: reloadFeed) {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
    
    /// Select a user/instance, or logout.
    @ViewBuilder
    private var sessionPicker: some View {
        HStack {
            if person == myself?.localUserView.person {
                Picker("", selection: $selectededSession) {
                    ForEach(sessions, id: \.self) { session in
                        if sessions.last == session {
                            Divider()
                        }
                        Text(session.title)
                    }
                }
                .frame(maxWidth: 120)
                .onChange(of: selectededSession) { change in
                    performSwitch(change)
                }
                Button("Logout", action: { showLogoutAlert = true })
                    .alert("Logout", isPresented: $showLogoutAlert, actions: {
                        Button("Logout", role: .destructive) { logout() }
                        Button("Cancel", role: .cancel) {}
                    }, message: {
                        Text("Are you sure you want to logout?")
                    })
            }
        }
    }
    
    // MARK: -
    
    func logout() {
        let toDestroy = SessionStorage.getInstance.getCurrentSession()
        if SessionStorage.getInstance.getAllSessions().count > 1 {
            // Is there more than 1 session stored? Switch to the one that's not used
            if SessionStorage.getInstance.getAllSessions()[0] == toDestroy {
                _ = SessionStorage.getInstance.setCurrentSession(SessionStorage.getInstance.getAllSessions()[1])
            } else {
                _ = SessionStorage.getInstance.setCurrentSession(SessionStorage.getInstance.getAllSessions()[0])
            }
            
            // Destroy the session
            _ = SessionStorage.getInstance.remove(session: toDestroy!)
            
            self.contentView.navigateToFeed()
            self.contentView.loadUserData()
        } else {
            _ = SessionStorage.getInstance.endSession()
            _ = SessionStorage.getInstance.remove(session: toDestroy!)
            contentView.navigateToFeed()
            contentView.logout()
        }
    }
    
    func loadPersonDetails() {
        if page == 1 && self.personDetails != nil {
            self.personDetails!.comments = []
            self.personDetails!.posts = []
        }
        
        self.personService?.getPersonDetails(person: person, page: page, savedOnly: selectedBrowseOption.id == 2, sortType: selectedSort) { result in
            switch result {
            case .success(let personDetails):
                DispatchQueue.main.sync {
                    if self.personDetails != nil {
                        self.personDetails!.posts += personDetails.posts.filter { !self.personDetails!.posts.contains($0) }
                        self.personDetails!.comments += personDetails.comments.filter { !self.personDetails!.comments.contains($0) }
                    } else {
                        self.personDetails = personDetails
                    }
                    if self.personDetails?.personView.person == myself?.localUserView.person {
                        loadSessions()
                    }
                }
                
                page += 1
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func reloadFeed() {
        page = 1
        loadPersonDetails()
    }
    
    func loadPostFromComment(commentView: CommentView) {
        self.postService?.getPostForComment(comment: commentView.comment) { result in
            switch result {
            case .success(let getPostResponse):
                self.contentView.openPost(postView: getPostResponse.postView)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func loadSessions() {
        if self.sessions.count == 0 {
            for session in SessionStorage.getInstance.getAllSessions() {
                let sessionPickerOption = SessionPickerOption(title: "\(session.name)@\(session.lemmyInstance)", sessionInfo: session)
                self.sessions.append(sessionPickerOption)
                
                if SessionStorage.getInstance.getCurrentSession() == session {
                    self.selectededSession = sessionPickerOption
                }
            }
            self.sessions.append(SessionPickerOption(title: "Add New", sessionInfo: nil))
        }
    }
    
    fileprivate func performSwitch(_ selection: SessionPickerOption) {        
        if let sessionInfo = selection.sessionInfo {
            let sessionNameAndInstance = (sessionInfo.name + "@" + sessionInfo.lemmyInstance).lowercased()
            if let myself = self.myself {
                let myselfSessionAndInstance = (myself.localUserView.person.name + "@" + LinkHelper.stripToHost(link: myself.localUserView.person.actorId)).lowercased()
                // Do not do anything, if selected is the same as current logged in user.
                if myselfSessionAndInstance == sessionNameAndInstance {
                    return
                }
                
                let sessionChanged = SessionStorage.getInstance.setCurrentSession(sessionInfo)
                if !sessionChanged {
                    sessionChangeFail = true
                    return
                }
                
                self.contentView.navigateToFeed()
                self.contentView.loadUserData()
            }
        } else {
            // Add user.
            self.contentView.addNewUserLogin()
        }
    }
}

fileprivate struct SessionPickerOption: Hashable {
    let title: String
    let sessionInfo: SessionInfo?
}
