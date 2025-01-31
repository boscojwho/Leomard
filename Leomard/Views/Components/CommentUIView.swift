//
//  CommentUIView.swift
//  Leomard
//
//  Created by Konrad Figura on 03/07/2023.
//

import Foundation
import SwiftUI
import MarkdownUI

struct CommentUIView: View {
    @State var commentView: CommentView
    let indentLevel: Int
    let commentService: CommentService
    @Binding var myself: MyUserInfo?
    @State var post: Post
    let contentView: ContentView
    
    static let intentOffset: Int = 8
    static let limit: Int = 10
    
    @State var commentBody: String = ""
    
    @State var subComments: [CommentView] = []
    @State var page: Int = 1
    @State var lastResultEmpty: Bool = false
    @State var hidden: Bool = false
    
    @State var isReplying: Bool = false
    @State var commentText: String = ""
    @FocusState var isSendingComment: Bool
    @State var isEditingComment: Bool = false
    @State var updatedTimeAsString: String = ""
    @State var showConfirmDelete: Bool = false
    
    @State var startRemove: Bool = false
    @State var removalReason: String = ""
    
    @State var profileViewMode: Bool = false
    
    let subcommentsColorsOrder: [Color] = [
        .red, .orange, .green, .blue, .purple
    ]
    
    var body: some View {
        if commentView.comment.deleted {
            VStack {
                Text("Comment deleted by the user.")
                    .italic()
                    .foregroundColor(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                Divider()
            }
        } else if commentView.comment.removed {
            VStack {
                Text("Comment removed by moderator.")
                    .italic()
                    .foregroundColor(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                Divider()
            }
        } else {
            HStack {
                if self.indentLevel > 0 && !self.profileViewMode {
                    VStack {
                        EmptyView()
                    }
                    .frame(maxWidth: 4, maxHeight: .infinity, alignment: .topLeading)
                    .background(subcommentsColorsOrder[(indentLevel - 1) % (subcommentsColorsOrder.count + 1)])
                    .cornerRadius(8)
                }
                LazyVStack {
                    HStack {
                        HStack {
                            PersonDisplay(person: commentView.creator, myself: $myself)
                                .onTapGesture {
                                    contentView.openPerson(profile: commentView.creator)
                                    
                                }
                            if commentView.post.creatorId == commentView.creator.id {
                                HStack {
                                    Text("OP")
                                        .padding(2)
                                        .foregroundColor(.white)
                                        .font(.system(size: 8))
                                }
                                .background(Color(.linkColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            HStack {
                                Image(systemName: "arrow.up")
                                Text(String(commentView.counts.upvotes))
                            }
                            .foregroundColor(commentView.myVote != nil && commentView.myVote! > 0 ? .orange : .primary)
                            .onTapGesture {
                                likeComment()
                            }
                            HStack {
                                Image(systemName: "arrow.down")
                                Text(String(commentView.counts.downvotes))
                            }
                            .foregroundColor(commentView.myVote != nil && commentView.myVote! < 0 ? .blue : .primary)
                            .onTapGesture {
                                dislikeComment()
                            }
                            if commentView.counts.childCount > 0 {
                                HStack {
                                    Image(systemName: "ellipsis.message")
                                    Text(String(commentView.counts.childCount))
                                }
                            }
                            DateDisplayView(date: self.commentView.comment.published)
                            if commentView.comment.updated != nil {
                                HStack {
                                    Image(systemName: "pencil")
                                    
                                }.help(updatedTimeAsString)
                            }
                            if commentView.comment.distinguished {
                                HStack {
                                    Image(systemName: "star.circle")
                                        .foregroundColor(Color.yellow)
                                }
                            }
                        }
                        .frame(
                            minWidth: 0,
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        if myself != nil {
                            HStack {
                                if commentView.creator.actorId == myself?.localUserView.person.actorId {
                                    Button(action: startEditComment) {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.link)
                                    .foregroundColor(.primary)
                                    Button(action: { showConfirmDelete = true }) {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.link)
                                    .foregroundColor(.primary)
                                    .alert("Confirm", isPresented: $showConfirmDelete, actions: {
                                        Button("Delete", role: .destructive) { deleteComment() }
                                        Button("Cancel", role: .cancel) {}
                                    }, message: {
                                        Text("Are you sure you want to delete a comment?")
                                    })
                                }
                                Button(action: savePost) {
                                    Image(systemName: "bookmark")
                                }
                                .buttonStyle(.link)
                                .foregroundColor(commentView.saved ? .green : .primary)
                                Button(action: startReply) {
                                    Image(systemName: "arrowshape.turn.up.left")
                                }
                                .buttonStyle(.link)
                                .foregroundColor(.primary)
                            }
                            .frame(
                                minWidth: 0,
                                alignment: .trailing
                            )
                        }
                    }
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    if self.hidden {
                        Button("...", action: showComment)
                            .buttonStyle(.plain)
                            .foregroundColor(Color(.secondaryLabelColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        let content = MarkdownContent(commentBody)
                        Markdown(content)
                            .lineLimit(nil)
                            .frame(
                                minWidth: 0,
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .onTapGesture {
                                if self.profileViewMode {
                                    contentView.openPostForComment(comment: self.commentView.comment)
                                } else {
                                    hideComment()
                                }
                            }
                            .contextMenu {
                                CommentContextMenu(contentView: self.contentView, commentView: self.commentView, onDistinguish: distinguish, onRemove: {
                                    startRemove = true
                                })
                            }
                        if isReplying || isEditingComment {
                            Spacer()
                            VStack {
                                Text(isEditingComment ? "Edit" : "Reply")
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .fontWeight(.semibold)
                                TextEditor(text: $commentText)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary, lineWidth: 0.5))
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 3 * NSFont.preferredFont(forTextStyle: .body).xHeight,
                                        maxHeight: .infinity,
                                        alignment: .leading
                                    )
                                    .lineLimit(5...)
                                    .font(.system(size: NSFont.preferredFont(forTextStyle: .body).pointSize))
                                HStack {
                                    Button(isEditingComment ? "Save" : "Send", action: onSaveSendCommentClick)
                                        .buttonStyle(.borderedProminent)
                                        .frame(
                                            alignment: .leading
                                        )
                                        .disabled(!isSendable())
                                    Button("Cancel", action: cancelComment)
                                        .buttonStyle(.automatic)
                                        .frame(
                                            alignment: .leading
                                        )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .leading
                                )
                            }
                            .frame(
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                        }
                        if (subComments.count > 0 || commentView.counts.childCount > 0) && !profileViewMode {
                            Spacer()
                            ForEach(subComments, id: \.self) { commentView in
                                CommentUIView(commentView: commentView, indentLevel: self.indentLevel + 1, commentService: commentService, myself: $myself, post: post, contentView: contentView)
                                    .frame(maxHeight: .infinity, alignment: .leading)
                                if commentView != self.subComments.last {
                                    Divider()
                                        .padding(.leading, 20)
                                }
                                Spacer()
                            }
                            if !lastResultEmpty {
                                Divider()
                                Button("Load replies", action: loadSubcomments)
                                    .buttonStyle(.plain)
                                    .foregroundColor(Color(.secondaryLabelColor))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, CGFloat(CommentUIView.intentOffset))
                            }
                        }
                    }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
                .task {
                    if self.indentLevel == 0 && self.commentView.counts.childCount > 0 {
                        loadSubcomments()
                    }
                    
                    if commentView.comment.updated != nil {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                        updatedTimeAsString = dateFormatter.string(from: commentView.comment.updated!)
                    }
                    
                    self.commentBody = await commentView.comment.content.formatMarkdown()
                }
            }
            .padding(.leading, CGFloat(CommentUIView.intentOffset * self.indentLevel))
            .alert("Remove Comment (Mod)", isPresented: $startRemove, actions: {
                TextField("Optional", text: $removalReason)
                Button("Remove", role: .destructive) {
                    self.commentService.remove(comment: commentView.comment, removed: true, reason: removalReason) { result in
                        switch result {
                        case .success(let commentResponse):
                            self.commentView = commentResponse.commentView
                        case .failure(let error):
                            print(error)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }, message: {
                Text("State the reason of removal:")
            })
        }
    }
    
    func loadSubcomments() {
        self.commentService.getSubcomments(comment: self.commentView.comment, page: page, level: self.indentLevel + 1) { result in
            switch result {
            case .success(let getCommentView):
                self.subComments += getCommentView.comments.filter { !self.subComments.contains($0) }
                page += 1
                if getCommentView.comments.count == 0 || getCommentView.comments.count < CommentUIView.limit {
                    self.lastResultEmpty = true
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func hideComment() {
        if !self.profileViewMode {
            self.hidden = true
        }
    }
    
    func showComment() {
        self.hidden = false
    }
    
    func likeComment() {
        if myself == nil {
            return
        }
        
        var score = 1
        if commentView.myVote == 1 {
            score = 0
        }
        self.commentService.setCommentLike(comment: commentView.comment, score: score) { result in
            switch result {
            case .success(let commentResponse):
                self.commentView = commentResponse.commentView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func dislikeComment() {
        if myself == nil {
            return
        }
        
        var score = -1
        if commentView.myVote == -1 {
            score = 0
        }
        self.commentService.setCommentLike(comment: commentView.comment, score: score) { result in
            switch result {
            case .success(let commentResponse):
                self.commentView = commentResponse.commentView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func startReply() {
        isReplying = true
    }
    
    func onSaveSendCommentClick() {
        if !isSendable() {
            return
        }
        
        isSendingComment = true
        let comment = commentText
        
        if isEditingComment {
            commentService.updateComment(comment: commentView.comment, content: comment) { result in
                switch result {
                case .success(let commentResponse):
                    DispatchQueue.main.sync {
                        commentView = commentResponse.commentView
                        commentText = ""
                        isReplying = false
                        isSendingComment = false
                        isEditingComment = false
                    }
                case .failure(let error):
                    print(error)
                }
            }
        } else {
            commentService.createComment(content: comment, post: post, parent: commentView.comment) { result in
                switch result {
                case .success(let commentResponse):
                    DispatchQueue.main.sync {
                        subComments.insert(commentResponse.commentView, at: 0)
                        commentText = ""
                        isReplying = false
                        isSendingComment = false
                        isEditingComment = false
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    func isSendable() -> Bool {
        return commentText.count > 0 && !isSendingComment
    }
    
    func cancelComment() {
        commentText = ""
        isReplying = false
        isEditingComment = false
    }
    
    func deleteComment() {
        commentService.deleteComment(comment: commentView.comment) { result in
            switch result {
            case .success(_):
                self.commentView.comment.deleted = true
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func startEditComment() {
        isEditingComment = true
        commentText = commentView.comment.content
    }
    
    func savePost() {
        let save = !commentView.saved
        self.commentService.saveComment(comment: commentView.comment, save: save) { result in
            switch result {
            case .success(let commentResponse):
                self.commentView = commentResponse.commentView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func distinguish() {
        commentService.distinguish(comment: commentView.comment, distinguished: !commentView.comment.distinguished) { result in
            switch result {
            case .success(let commentResponse):
                self.commentView = commentResponse.commentView
            case .failure(let error):
                print(error)
            }
        }
    }
}
