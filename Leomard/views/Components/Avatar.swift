//
//  UserIconImage.swift
//  Leomard
//
//  Created by Konrad Figura on 04/07/2023.
//

import Foundation
import SwiftUI

extension Image {
    func AvatarFormatting(size: CGFloat) -> some View {
        return self.resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .scaledToFit()
            .frame(width: size, height: size, alignment: .leading)
            .clipShape(Circle())
    }
}

struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 20
    
    var body: some View {
        if person.avatar != nil {
            AsyncImage(url: URL(string: person.avatar!),
                       content: { phase in
                switch phase {
                case .success(let image):
                    image.AvatarFormatting(size: size)
                default:
                    Image(systemName: "person.circle")
                        .AvatarFormatting(size: size)
                }
            })
        } else {
            Image(systemName: "person.circle")
                .AvatarFormatting(size: size)
        }
    }
}

struct CommunityAvatar: View {
    let community: Community
    var size: CGFloat = 20
    
    var body: some View {
        if community.icon != nil {
            AsyncImage(url: URL(string: community.icon!),
                       content: { phase in
                switch phase {
                case .success(let image):
                    image.AvatarFormatting(size: size)
                default:
                    Image(systemName: "person.2.circle")
                        .AvatarFormatting(size: size)
                }
            })
        } else {
            Image(systemName: "person.2.circle")
                .AvatarFormatting(size: size)
        }
    }
}

