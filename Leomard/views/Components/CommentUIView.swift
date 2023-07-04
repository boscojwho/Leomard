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
    static let intentOffset: Int = 15
    static let limit: Int = 10
    
    @State var subComments: [CommentView] = []
    @State var page: Int = 1
    @State var lastResultEmpty: Bool = false
    @State var hidden: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                PersonDisplay(person: commentView.creator)
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
                let content = MarkdownContent(commentView.comment.content)
                Markdown(content)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .onTapGesture {
                        hideComment()
                    }
                if commentView.counts.childCount > 0 {
                    Spacer()
                    ForEach(subComments, id: \.self) { commentView in
                        CommentUIView(commentView: commentView, indentLevel: self.indentLevel + 1, commentService: commentService)
                        if commentView != self.subComments.last {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                    if !lastResultEmpty {
                        Divider()
                        Button("Load more...", action: loadSubcomments)
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
            alignment: .leading
            )
        .padding(.leading, CGFloat(CommentUIView.intentOffset * self.indentLevel))
        .task {
            if self.indentLevel == 0 && self.commentView.counts.childCount > 0 {
                loadSubcomments()
            }
        }
    }
    
    func loadSubcomments() {
        self.commentService.getSubcomments(comment: self.commentView.comment, page: page, level: self.indentLevel + 1) { result in
            switch result {
            case .success(let getCommentView):
                self.subComments = self.subComments + getCommentView.comments
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
        self.hidden = true
    }
    
    func showComment() {
        self.hidden = false
    }
    
    func likeComment() {
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
}
