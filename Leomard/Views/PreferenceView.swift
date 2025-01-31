//
//  PreferenceView.swift
//  Leomard
//
//  Created by Konrad Figura on 08/07/2023.
//

import Foundation
import SwiftUI

fileprivate struct FrequencyOption: Hashable, Equatable {
    let name: String
    let seconds: Int
}

struct PreferencesView: View {
    let checkForUpdateMethod: () -> Void
    
    fileprivate let preferenceOptions: [PreferenceOption] = [
        .init(name: "General", icon: "gearshape", color: .blue),
        .init(name: "Content", icon: "text.alignleft", color: .cyan),
        .init(name: "Updates", icon: "square.and.arrow.down.on.square", color: .green)
        //.init(name: "Experimental", icon: "testtube.2", color: .red)
    ]
    @State fileprivate var currentSelection: PreferenceOption?
    
    fileprivate let notificationCheckFrequencies: [FrequencyOption] = [
        .init(name: "Never", seconds: -1),
        .init(name: "10 seconds", seconds: 10),
        .init(name: "30 seconds", seconds: 30),
        .init(name: "1 minute", seconds: 60),
        .init(name: "3 minutes", seconds: 60 * 3),
        .init(name: "10 minutes", seconds: 60 * 10)
    ]
    @State fileprivate var selectedNotificaitonCheckFrequency: FrequencyOption = .init(name: "Err", seconds: 60)
    @State var manuallyCheckedForUpdate: Bool = false
    
    var body: some View {
        NavigationSplitView {
            preferencesSidebar
                .listStyle(SidebarListStyle())
                .navigationBarBackButtonHidden(true)
        } detail: {
            preferencePanel(for: currentSelection)
                .padding(.leading)
                .padding(.trailing)
                .listStyle(SidebarListStyle())
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity)
        }
        .task {
            self.currentSelection = self.preferenceOptions[0]
        
            for notificationCheckFrequency in notificationCheckFrequencies {
                if UserPreferences.getInstance.checkNotifsEverySeconds == notificationCheckFrequency.seconds {
                    selectedNotificaitonCheckFrequency = notificationCheckFrequency
                    break
                }
            }
            if selectedNotificaitonCheckFrequency.name == "Err" {
                selectedNotificaitonCheckFrequency = notificationCheckFrequencies[3]
            }
        }
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var preferencesSidebar: some View {
        List {
            ForEach(preferenceOptions, id: \.self) { option in
                preferenceSidebarItem(option: option)
                    .padding(.bottom, 10)
                    .onTapGesture {
                        self.currentSelection = option
                    }
            }
        }
    }
    
    @ViewBuilder
    private func preferenceSidebarItem(option: PreferenceOption) -> some View {
        HStack {
            VStack {
                Image(systemName: option.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: 14,
                        height: 14
                    )
                    .foregroundColor(.white)
                    .padding(3)
            }
            .background(option.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(
                width: 20, height: 20
            )
            .shadow(radius: 0.5)
            Text(option.name)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .foregroundColor(currentSelection == option ? Color(.linkColor) : Color(.labelColor))
            Spacer()
        }
    }
    
    // MARK: - Detail
    
    @ViewBuilder
    private func preferencePanel(for currentSelection: PreferenceOption?) -> some View {
        List {
            VStack(alignment: .leading, spacing: 20) {
                switch currentSelection {
                case preferenceOptions[0]:
                    generalPreferences
                case preferenceOptions[1]:
                    contentPreferences
                case preferenceOptions[2]:
                    updatesPreferences
                //case preferenceOptions[3]:
                    //experimentalPreferences
                default:
                    Text("")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var generalPreferences: some View {
        VStack{
            Picker("Check notifications every", selection: $selectedNotificaitonCheckFrequency) {
                ForEach(self.notificationCheckFrequencies, id: \.self) { option in
                    Text(option.name)
                }
            }
            .onChange(of: selectedNotificaitonCheckFrequency) { value in
                UserPreferences.getInstance.checkNotifsEverySeconds = value.seconds
            }
            Text("Note: Notifications are not checked when app is closed.")
                .frame(maxWidth: .infinity, alignment:.leading)
                .lineLimit(nil)
        }
        VStack(alignment: .leading) {
            Text("Inbox")
            Toggle("Show Unread only by default", isOn: UserPreferences.getInstance.$unreadonlyWhenOpeningInbox)
        }
        VStack(alignment: .leading) {
            Toggle("Followed List: Show Letter Separators", isOn: UserPreferences.getInstance.$navbarShowLetterSeparators)
        }
        GroupBox("Prefer Display Name") {
            VStack {
                Text("Communities")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Posts", isOn: UserPreferences.getInstance.$preferDisplayNameCommunityPost)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Followed", isOn: UserPreferences.getInstance.$preferDisplayNameCommunityFollowed)
                        .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            VStack {
                Toggle("People", isOn: UserPreferences.getInstance.$preferDisplayNamePeoplePost)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var contentPreferences: some View {
        VStack(alignment: .leading) {
            Picker("Default post sort method", selection: UserPreferences.getInstance.$postSortMethod) {
                ForEach(UserPreferences.getInstance.sortTypes, id: \.self) { method in
                    Text(String(describing: method))
                }
            }
            Picker("Default comment sort method", selection: UserPreferences.getInstance.$commentSortMethod) {
                ForEach(CommentSortType.allCases, id: \.self) { method in
                    Text(String(describing: method))
                }
            }
            Picker("Default listing type", selection: UserPreferences.getInstance.$listType) {
                ForEach(ListingType.allCases, id: \.self) { method in
                    Text(String(describing: method))
                }
            }
            Picker("Default profile sort method", selection: UserPreferences.getInstance.$profileSortMethod) {
                ForEach(UserPreferences.getInstance.profileSortTypes, id: \.self) { method in
                    Text(String(describing: method))
                }
            }
        }
        VStack(alignment: .leading) {
            Toggle("Compact View", isOn: UserPreferences.getInstance.$usePostCompactView)
        }
        VStack(alignment: .leading) {
            Text("NSFW")
            Toggle("Show NSFW content", isOn: UserPreferences.getInstance.$showNsfw)
            Toggle("Show NSFW content in Feed", isOn: UserPreferences.getInstance.$showNsfwInFeed)
                .padding(.leading, 16)
            Toggle("Blur NSFW content", isOn: UserPreferences.getInstance.$blurNsfw)
        }
        GroupBox("Mark Post As Read") {
            Toggle("When opening the post", isOn: UserPreferences.getInstance.$markPostAsReadOnOpen)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("When voting on post", isOn: UserPreferences.getInstance.$markPostAsReadOnVote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        VStack {
            Toggle("Hide Read Posts", isOn: UserPreferences.getInstance.$hideReadPosts)
        }
        VStack(alignment: .leading) {
            Text("Hidden Instances")
            TextField("Hidden Instances", text: UserPreferences.getInstance.$blockedInstances, prompt: Text("ex.: instance1.com, instance2.org"))
                .textFieldStyle(.roundedBorder)
            Text("Any instances listed here will be filtered out. You won't see communities, posts, or comments from those instances. Simply type the hostname of the instance (comma-separated).")
                .lineLimit(nil)
        }
    }
    
    @ViewBuilder
    private var updatesPreferences: some View {
        VStack(alignment: .leading) {
            Picker("Check for updates", selection: UserPreferences.getInstance.$checkForUpdateFrequency) {
                ForEach(UpdateFrequency.allCases, id: \.self) { option in
                    Text(String(describing: option))
                }
            }
            HStack(spacing: 10) {
                Button("Check for update", action: {
                    self.checkForUpdateMethod()
                    manuallyCheckedForUpdate = true
                })
                .disabled(manuallyCheckedForUpdate)
                Text("Last updated:")
                DateDisplayView(date: UserPreferences.getInstance.lastUpdateCheckDate, showRealTime: true, noBrackets: true, noTapAction: true)
                if manuallyCheckedForUpdate {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private var experimentalPreferences: some View {
        VStack(alignment: .leading) {
            // Unused for now.
        }
    }
}

fileprivate struct PreferenceOption: Hashable {
    let name: String
    let icon: String
    let color: Color
}
