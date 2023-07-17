//
//  InboxView.swift
//  Leomard
//
//  Created by Konrad Figura on 12/07/2023.
//

import Foundation
import SwiftUI

struct InboxView: View {
    let repliesService: RepliesService
    let requestHandler: RequestHandler
    @Binding var myself: MyUserInfo?
    let contentView: ContentView
    let commentService: CommentService
    
    @State var privateMessageService: PrivateMessageService? = nil
    
    let views: [Option] = [
        .init(id: 0, title: "Replies", imageName: "ellipsis.message"),
        .init(id: 1, title: "Private Messages", imageName: "mail")
    ]
    @State var selectedView: Option = .init(id: 0, title: "Replies", imageName: "ellipsis.message")
    @State var selectedCommentSortType: CommentSortType = .new
    
    @State var commentReplies: [CommentReplyView] = []
    @State var privateMessages: [PrivateMessageView] = []
    @State var page: Int = 1
    @State var unreadOnly: Bool = UserPreferences.getInstance.unreadonlyWhenOpeningInbox
    @State var reachedEnd: Bool = false
    
    @State var isLoading: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: selectedView.imageName)
                    .padding(.trailing, 0)
                Picker("", selection: $selectedView) {
                    ForEach(views, id: \.self) { method in
                        Text(String(describing: method.title))
                    }
                }
                .frame(maxWidth: 160)
                .padding(.leading, -10)
                .onChange(of: selectedView) { value in
                    self.page = 1
                    self.loadContent()
                }
                if selectedView == views[0] {
                    Image(systemName: selectedCommentSortType.image)
                        .padding(.trailing, 0)
                    Picker("", selection: $selectedCommentSortType) {
                        ForEach(CommentSortType.allCases, id: \.self) { method in
                            Text(String(describing: method))
                        }
                    }
                    .frame(maxWidth: 80)
                    .padding(.leading, -10)
                    .onChange(of: selectedCommentSortType) { value in
                        self.page = 1
                        self.loadContent()
                    }
                }
                Button(action: {
                    self.page = 1
                    self.loadContent()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                Toggle("Unread Only", isOn: $unreadOnly)
                    .onChange(of: unreadOnly) { value in
                        self.page = 1
                        self.loadContent()
                    }
                Spacer()
                if selectedView == views[0] {
                    Button(action: markAllAsRead) {
                        Image(systemName: "envelope.open")
                    }.buttonStyle(.link)
                }
            }
            .padding(.leading)
            .padding(.trailing)
            List {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                switch selectedView {
                case views[1]:
                    if privateMessages.count == 0 && !isLoading {
                        Text("You don't have any private messages.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    ForEach(privateMessages, id: \.self) { privateMessage in
                        PrivateMessageUIView(privateMessageView: privateMessage, privateMessageService: privateMessageService!, myself: $myself, contentView: self.contentView, unreadOnlyMode: $unreadOnly)
                            .onAppear {
                                if privateMessage == privateMessages.last {
                                    page += 1
                                    loadContent()
                                }
                            }
                        Spacer()
                    }
                default:
                    if commentReplies.count == 0 && !isLoading {
                        Text("You don't have any replies.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    ForEach(commentReplies, id: \.self) { commentReply in
                        CommentReplyUIView(commentReplyView: commentReply, commentService: commentService, myself: $myself, contentView: contentView, unreadOnlyMode: $unreadOnly)
                            .onAppear {
                                if commentReply == commentReplies.last {
                                    page += 1
                                    loadContent()
                                }
                            }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: 600, maxHeight: .infinity)
            if selectedView == views[1] {
                Spacer()
                Text("DISCLAIMER: Private messages in Lemmy are not secure.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            self.privateMessageService = PrivateMessageService(requestHandler: requestHandler)
            self.selectedView = views[0]
            
            self.loadContent()
        }
    }
    
    func loadContent() {
        if page == 1 {
            self.commentReplies = []
            self.privateMessages = []
            self.reachedEnd = false
        }
        
        if reachedEnd {
            return
        }
        
        self.isLoading = true
        
        switch selectedView {
        case views[1]:
            self.privateMessageService!.getPrivateMessages(unreadOnly: self.unreadOnly, page: self.page) { result in
                switch result {
                case .success(let privateMessagesResponse):
                    self.isLoading = false
                    self.privateMessages += privateMessagesResponse.privateMessages
                    
                    if privateMessagesResponse.privateMessages.count == 0 {
                        reachedEnd = true
                    }
                    
                case .failure(let error):
                    print(error)
                    self.isLoading = false
                }
            }
        default:
            self.repliesService.getReplies(unreadOnly: self.unreadOnly, sortType: self.selectedCommentSortType, page: page) { result in
                switch result {
                case .success(let repliesResponse):
                    self.isLoading = false
                    self.commentReplies += repliesResponse.replies
                    
                    if repliesResponse.replies.count == 0 {
                        reachedEnd = true
                    }
                    
                case .failure(let error):
                    print(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func markAllAsRead() {
        self.repliesService.markAllAsRead { result in
            switch result {
            case .success(_):
                if self.unreadOnly {
                    self.commentReplies = []
                } else {
                    self.page = 1
                    loadContent()
                }
                
                self.contentView.updateUnreadMessagesCount()
            case .failure(let error):
                print(error)
            }
        }
    }
}
