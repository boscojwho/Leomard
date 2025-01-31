//
//  LoginService.swift
//  Leomard
//
//  Created by Konrad Figura on 02/07/2023.
//

import Foundation

class LoginService: Service {
    private let requestHandler: RequestHandler
    
    private static let instancesList = "https://raw.githubusercontent.com/maltfield/awesome-lemmy-instances/main/awesome-lemmy-instances.csv"
    
    private var allInstances: [LemmyInstance] = []
    private var approvedInstances: [LemmyInstance] = []
    
    public init(requestHandler: RequestHandler) {
        self.requestHandler = requestHandler
    }
   
    public func login(lemmyInstance: String, login: Login,Ca completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        self.requestHandler.makeApiRequest(host: lemmyInstance, request: "/user/login", method: .post, body: login) { result in
            self.respond(result, completion)
        }
    }
    
    public func getLemmyInstances(completion: @escaping (Result<[LemmyInstance], Error>) -> Void) {
        guard let url = URL(string: LoginService.instancesList) else {
            completion(.failure(URLError.init(.badURL)))
            return
        }
        
        let session = URLSession.shared
        session.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                
                completion(.failure(URLError.init(.badURL)))
                return
            }
            
            if let csvString = String(data: data, encoding: .utf8) {
                let csvRows = csvString.components(separatedBy: "\n").map { $0.components(separatedBy: ",")}
                
                for row in csvRows {
                    if csvRows.first == row {
                        // First is just the header.
                        continue
                    }
   
                    let nameAndUrl = row[0]
                    if nameAndUrl == "" {
                        continue
                    }
                    
                    let federated = row[3] == "Yes"
                    let users = Int(row[6])!
                    let blockedBy = Int(row[8])!
                    let upTime = Double(row[9].replacingOccurrences(of: "%", with: "")) ?? 0
                
                    let name: String = nameAndUrl.split(separator: "]").map(String.init)[0].replacingOccurrences(of: "[", with: "")
                    let link: String = nameAndUrl.split(separator: "(").map(String.init)[1].replacingOccurrences(of: ")", with: "")
                    let lemmyInstance = LemmyInstance(name: name, url: link)
                    
                    self.allInstances.append(lemmyInstance)
                    
                    // Instance to show rules:
                    // - Must be federated and not NSFW.
                    // - Must have 500 users (or more)
                    // - Must not be blocked by more than 10 other instanes
                    // - Uptime must be larger than 95%
                    if !federated || users < 500 || blockedBy >= 10 || upTime < 0.95 {
                        continue
                    }
                    
                    self.approvedInstances.append(lemmyInstance)
                }
                
                completion(.success(self.approvedInstances))
                return
            }
            completion(.failure(URLError.init(.badURL)))
        }.resume()
    }
    
    public func searchInstance(query: String, completion: @escaping (Result<[LemmyInstance], Error>) -> Void) {
        if query.count == 0 {
            completion(.success(self.approvedInstances))
            return
        }
        
        var result: [LemmyInstance] = []
        for instance in self.allInstances {
            if instance.name.lowercased().contains(query.lowercased()) || instance.url.lowercased().contains(query.lowercased()) {
                result.append(instance)
            }
        }
        
        completion(.success(result))
    }
}
