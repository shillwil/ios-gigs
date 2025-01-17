//
//  GigController.swift
//  ios-gigs-afternoon-project
//
//  Created by Alex Shillingford on 6/19/19.
//  Copyright © 2019 Alex Shillingford. All rights reserved.
//

import Foundation
// MARK: - Enums
enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

enum NetworkError: Error {
    case noAuth
    case badAuth
    case otherError
    case badData
    case noDecode
    case noEncode
}


// MARK: - GigController Class
class GigController {
    
    // MARK: - Properties
    var bearer: Bearer?
    private let baseURL = URL(string: "https://lambdagigs.vapor.cloud/api")!
    var gigs: [Gig] = []
    
    //MARK: - Methods and Functions
    func signUp(user: User, completion: @escaping (Error?) -> ()) {
        let signUpURL = baseURL.appendingPathComponent("/users/signup")
        
        var request = URLRequest(url: signUpURL)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(user)
            request.httpBody = jsonData
        } catch {
            print("Error encoding User Object: \(error)")
            completion(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let response = response as? HTTPURLResponse,
                response.statusCode != 200 {
                completion(NSError(domain: "", code: response.statusCode, userInfo: nil))
                return
            }
            
            if let error = error {
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    } // Closing brace for signUp() method
    
    func signIn(user: User, completion: @escaping (Error?) -> ()) {
        let signInURL = baseURL.appendingPathComponent("/users/login")
        
        var request = URLRequest(url: signInURL)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(user)
            request.httpBody = jsonData
        } catch {
            print("Error encoding User Object: \(error)")
            completion(error)
        }
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let response = response as? HTTPURLResponse,
                response.statusCode != 200 {
                completion(NSError(domain: "", code: response.statusCode, userInfo: nil))
                return
            }
            
            if let error = error {
                completion(error)
                return
            }
            
            guard let data = data else {
                completion(NSError())
                return
            }
            
            do {
                let decoder = JSONDecoder()
                self.bearer = try decoder.decode(Bearer.self, from: data)
            } catch {
                print("Error decoding: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
            }.resume()
    }
    
    func fetchingAllGigs(completion: @escaping (Result<[Gig], NetworkError>) -> Void) {
        guard let bearer = bearer else {
            completion(.failure(.noAuth))
            return
        }
        
        let gigsURL = baseURL.appendingPathComponent("gigs")
        var request = URLRequest(url: gigsURL)
        
        request.httpMethod = HTTPMethod.get.rawValue
        request.addValue("Bearer \(bearer.token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let response = response as? HTTPURLResponse,
                response.statusCode == 401 {
                completion(.failure(.badAuth))
                return
            }
            
            if let _ = error {
                completion(.failure(.otherError))
                return
            }
            
            guard let data = data else {
                completion(.failure(.badData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                self.gigs = try decoder.decode([Gig].self, from: data)
                
                completion(.success(self.gigs))
            } catch {
                completion(.failure(.noDecode))
                return
            }
        }.resume()
    }
    
    func addGig(gigTitle: String, description: String, date: Date, completion: @escaping (Result<Gig, NetworkError>) -> Void) {
        let gig = Gig(title: gigTitle, description: description, dueDate: date)
        guard let bearer = bearer else {
            completion(.failure(.noAuth))
            return
        }
        
        let gigURL = baseURL.appendingPathComponent("/gigs")
        
        var request = URLRequest(url: gigURL)
        request.httpMethod = HTTPMethod.post.rawValue
        request.addValue(bearer.token, forHTTPHeaderField: "Authentication")
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(gig)
            request.httpBody = jsonData
        } catch {
            completion(.failure(.badData))
        }
        // Even though it's a POST, URLSession is just ensuring that the server received it and has it stored on their database as well, THEN you append the gig to the gigs array. Doing it in this block ensures your gigs array and the server array of gigs match up
        URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let response = response as? HTTPURLResponse,
                response.statusCode != 200 {
                completion(.failure(.badAuth))
                return
            }
            
            if let _ = error {
                completion(.failure(.otherError))
                return
            }
            
            self.gigs.append(gig)
            completion(.success(gig))
        }.resume()
    }
}
