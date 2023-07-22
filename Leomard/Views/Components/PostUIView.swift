//
//  PostView.swift
//  Leomard
//
//  Created by Konrad Figura on 03/07/2023.
//

import Foundation
import SwiftUI
import MarkdownUI
import Combine
import AVKit
import NukeUI

@MainActor
struct PostUIView: View {
    @State var postView: PostView
    let shortBody: Bool
    let postService: PostService
    @Binding var myself: MyUserInfo?
    let contentView: ContentView
    
    private static let maxPostLength: Int = 400
    private static let blurStrength: CGFloat = 50
    private static let cornerRadius: CGFloat = 8
    private static let padding: CGFloat = 12
    
    @State var postBody: String? = nil
    @State var url: URL? = nil
    @State var updatedTimeAsString: String = ""
    
    @State var showConfirmDelete: Bool = false
    
    @State var gifHeight: CGFloat = 400
    
    // Height retention variables
    @State var titleHeight: CGFloat = 0
    @State var bodyHeight: CGFloat = 0
    @State var imageHeight: CGFloat = 0

    @State private var performedTasksWillAppear = false
    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        if !postView.post.deleted && !postView.post.removed {
            LazyVStack {
                postTitle
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                postBodyMarkdown
                postBodyContent
                Spacer(minLength: 6)
                communityPersonDate
                    .frame (
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                Spacer(minLength: 6)
                postActionsToolbar
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
            .padding(Self.padding)
            .background(Color(.textBackgroundColor))
            .cornerRadius(Self.cornerRadius)
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: titleHeight + bodyHeight + imageHeight,
                maxHeight: .infinity,
                alignment: .top
            )

            .task {
                if performedTasksWillAppear == false {
                    performedTasksWillAppear = true
                    postBody = await postBodyTask()
                    url = await postUrlTask()
                    updatedTimeAsString = await updatedTimeAsStringTask()
                }
            }
            .onTapGesture {
                self.contentView.openPost(postView: self.postView)
            }
            .contextMenu {
                PostContextMenu(contentView: contentView, postView: self.postView)
            }
        }
    }
    
    nonisolated
    private func postBodyTask() async -> String? {
        return await withCheckedContinuation { continuation in
            Task(priority: .background) {
                var newPostBody = await self.postView.post.body?.formatMarkdown()
                if shortBody && newPostBody != nil && newPostBody!.count > PostUIView.maxPostLength {
                    newPostBody = String(newPostBody!.prefix(PostUIView.maxPostLength))
                    newPostBody = newPostBody!.trimmingCharacters(in: .whitespacesAndNewlines)
                    newPostBody = newPostBody! + "... **Read More**"
                }
                return continuation.resume(returning: newPostBody)
            }
        }
    }
    
    nonisolated
    private func postUrlTask() async -> URL? {
        return await withCheckedContinuation { continuation in
            Task(priority: .background) {
                guard let postUrl = await self.postView.post.url else {
                    return continuation.resume(returning: nil)
                }
                return continuation.resume(returning: URL(string: postUrl))
            }
        }
    }
    
    nonisolated
    private func updatedTimeAsStringTask() async -> String {
        return await withCheckedContinuation { continuation in
            Task(priority: .background) {
                guard let updatedDate = await self.postView.post.updated else {
                    return continuation.resume(returning: "")
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let dateString = dateFormatter.string(from: updatedDate)
                return continuation.resume(returning: dateString)
            }
        }
    }
    
    // MARK: -
    
    @ViewBuilder
    private var postTitle: some View {
        HStack {
            if postView.post.featuredCommunity {
                Image(systemName: "pin.fill")
                    .foregroundColor(.red)
            }
            Text(postView.post.name)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 24))
                .background(GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            self.titleHeight = geometry.size.height
                        }
                })
        }
    }
    
    @ViewBuilder
    private var postBodyMarkdown: some View {
        if let body = self.postBody {
            let content = MarkdownContent(body)
            Markdown(content)
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .lineLimit(nil)
                .textSelection(.enabled)
                .background(GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            self.bodyHeight = geometry.size.height
                        }
                })
        }
    }
    
    @ViewBuilder
    private var postBodyContent: some View {
        if postView.post.embedTitle != nil && postView.post.thumbnailUrl != nil {
            if LinkHelper.isYouTubeLink(link: postView.post.url!) {
                YoutubePlayer(link: postView.post.url!, imageHeight: $gifHeight)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: gifHeight, maxHeight: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                articleView
                    .onTapGesture {
                        openURL(url!)
                    }
            }
        } else if postView.post.url != nil && postView.post.embedTitle == nil {
            gifOrImage
            Spacer()
        } else if postView.post.embedVideoUrl != nil && LinkHelper.isVideosLink(link: postView.post.embedVideoUrl!) {
            VideoPlayer(player: AVPlayer(url: URL(string: postView.post.embedVideoUrl!)!))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var articleView: some View {
        VStack {
            Spacer()
            staticImage(postView.post.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(4)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                self.imageHeight = geometry.size.height
                            }
                    })
                    .blur(radius:(postView.post.nsfw || postView.community.nsfw) && UserPreferences.getInstance.blurNsfw && shortBody ? PostUIView.blurStrength : 0)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.top, 4)
            if LinkHelper.isWebp(link: postView.post.thumbnailUrl!) {
                Spacer()
            }
            Text(postView.post.url!)
                .foregroundColor(Color(.linkColor))
                .fixedSize(horizontal: false, vertical: false)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
        }
        .background(.ultraThickMaterial)
        .cornerRadius(4)
    }
    
    /// - Parameter imageBlock: Use this to modify the `Image` instance.
    /// - Returns: A wrapper view that contains an `Image` instance.
    @ViewBuilder
    private func staticImage(_ thumbnailUrl: String?, @ViewBuilder imageBlock: @escaping (Image) -> some View) -> some View {
        if let thumbnailUrl {
            LazyImage(url: .init(string: thumbnailUrl), transaction: .init(animation: .easeOut(duration: 0.2))) { state in
                if let image = state.image {
                    imageBlock(image)
                } else if state.error != nil {
                    Link("\(postView.post.url!)", destination: URL(string: postView.post.url!)!)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }.onDisappear(.lowerPriority)
        }
    }
    
    @ViewBuilder
    private var gifOrImage: some View {
        // Image-only view.
        if LinkHelper.isAnimatedLink(link: postView.post.url!) {
            // GIF
            AnimatedImage(link: postView.post.url!, imageHeight: $gifHeight)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: gifHeight, maxHeight: .infinity, alignment: .leading)
                .blur(radius: (postView.post.nsfw || postView.community.nsfw) && UserPreferences.getInstance.blurNsfw && shortBody ? PostUIView.blurStrength : 0)
        } else if LinkHelper.isImageLink(link: postView.post.url!) {
            // Static Images
            Spacer()
            Text("")
            if LinkHelper.isWebp(link: postView.post.url!) {
                Spacer()
            }
            staticImage(postView.post.url) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(minWidth:0, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                self.imageHeight = geometry.size.height
                            }
                    })
            }
            .blur(radius: (postView.post.nsfw || postView.community.nsfw) && UserPreferences.getInstance.blurNsfw && shortBody ? PostUIView.blurStrength : 0)
            if LinkHelper.isWebp(link: postView.post.url!) {
                Spacer()
            }
        } else {
            // Simple external link.
            let url = URL(string: postView.post.url!)!
            Link(url.absoluteString, destination: url)
        }
    }
    
    @ViewBuilder
    private var communityPersonDate: some View {
        LazyHStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("in")
                CommunityAvatar(community: postView.community)
                Text(self.postView.community.name)
                    .fontWeight(.semibold)
            }
            .onTapGesture {
                self.contentView.openCommunity(community: postView.community)
            }
            HStack(spacing: 4) {
                Text("by")
                PersonDisplay(person: postView.creator, myself: $myself)
                    .onTapGesture {
                        self.contentView.openPerson(profile: postView.creator)
                    }
            }
            DateDisplayView(date: self.postView.post.published)
            if postView.post.updated != nil {
                HStack {
                    Image(systemName: "pencil")
                    
                }.help(updatedTimeAsString)
            }
        }
    }
    
    /// Upvote, downvote, reply, bookmark, etc.
    @ViewBuilder
    private var postActionsToolbar: some View {
        HStack {
            HStack {
                Image(systemName: "arrow.up")
                Text(String(postView.counts.upvotes))
            }
            .foregroundColor(postView.myVote != nil && postView.myVote! > 0 ? .orange : .primary)
            .onTapGesture {
                likePost()
            }
            HStack {
                Image(systemName: "arrow.down")
                Text(String(postView.counts.downvotes))
            }
            .foregroundColor(postView.myVote != nil && postView.myVote! < 0 ? .blue : .primary)
            .onTapGesture {
                dislikePost()
            }
            HStack {
                Image(systemName: "ellipsis.message")
                Text(String(postView.counts.comments))
            }
            Spacer()
            if myself != nil {
                if postView.creator.actorId == myself?.localUserView.person.actorId {
                    Button(action: { startEditPost() } ) {
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
                        Button("Delete", role: .destructive) { deletePost() }
                        Button("Cancel", role: .cancel) {}
                    }, message: {
                        Text("Are you sure you want to delete a post?")
                    })
                }
                HStack {
                    Image(systemName: "bookmark")
                }
                .frame(alignment: .trailing)
                .foregroundColor(postView.saved ? .green : .primary)
                .onTapGesture {
                    savePost()
                }
            }
        }
    }
    
    // MARK: -
    
    func likePost() {
        if myself == nil {
            return
        }
        
        var score = 1
        if postView.myVote == 1 {
            score = 0
        }
        self.postService.setPostLike(post: postView.post, score: score) { result in
            switch result {
            case .success(let postResponse):
                self.postView = postResponse.postView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func dislikePost() {
        if myself == nil {
            return
        }
        
        var score = -1
        if postView.myVote == -1 {
            score = 0
        }
        self.postService.setPostLike(post: postView.post, score: score) { result in
            switch result {
            case .success(let postResponse):
                self.postView = postResponse.postView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func savePost() {
        let save = !postView.saved
        self.postService.savePost(post: postView.post, save: save) { result in
            switch result {
            case .success(let postResponse):
                self.postView = postResponse.postView
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func startEditPost() {
        self.contentView.openPostEdition(post: postView, onPostEdited: onPostEdited)
    }
    
    func deletePost() {
        self.postService.deletePost(post: postView.post, deleted: true) { result in
            switch result {
            case .success(_):
                self.postView.post.deleted = true
                self.contentView.closePost()
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func onPostEdited(updatedPostView: PostView) {
        self.postView = updatedPostView
        self.postBody = updatedPostView.post.body
    }
}
