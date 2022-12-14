//
//  HTTPTests.swift
//  PureSwift
//
//  Created by Alsey Coleman Miller on 8/28/17.
//  Copyright © 2017 PureSwift. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import HTTP

final class HTTPTests: XCTestCase {
    
    func testVersion() {
        XCTAssertEqual(HTTPVersion.v1.rawValue, "HTTP/1.0")
        XCTAssertEqual(HTTPVersion(rawValue: "HTTP/1.0"), .v1)
        XCTAssertEqual(HTTPVersion.v1_1.rawValue, "HTTP/1.1")
        XCTAssertEqual(HTTPVersion(rawValue: "HTTP/1.1"), .v1_1)
        XCTAssertEqual(HTTPVersion.v2.rawValue, "HTTP/2.0")
        XCTAssertEqual(HTTPVersion(rawValue: "HTTP/2.0"), .v2)
    }
    
    func testRequestMessage() {
        
        do {
            // GET /ping HTTP/1.1
            // Host: localhost:8456
            // Accept: */*
            // Accept-Language: en-US,en;q=0.9
            // Connection: keep-alive
            // Accept-Encoding: gzip, deflate
            // User-Agent: xctest/21250 CFNetwork/1398 Darwin/22.1.0
            
            let data = Data([
                71, 69, 84, 32, 47, 112, 105, 110, 103, 32, 72, 84, 84, 80, 47, 49, 46, 49,
                13, 10,
                72, 111, 115, 116, 58, 32, 108, 111, 99, 97, 108, 104, 111, 115, 116, 58, 56, 52, 53, 54,
                13, 10,
                65, 99, 99, 101, 112, 116, 58, 32, 42, 47, 42,
                13, 10,
                65, 99, 99, 101, 112, 116, 45, 76, 97, 110, 103, 117, 97, 103, 101, 58, 32, 101, 110, 45, 85, 83, 44, 101, 110, 59, 113, 61, 48, 46, 57,
                13, 10,
                67, 111, 110, 110, 101, 99, 116, 105, 111, 110, 58, 32, 107, 101, 101, 112, 45, 97, 108, 105, 118, 101,
                13, 10,
                65, 99, 99, 101, 112, 116, 45, 69, 110, 99, 111, 100, 105, 110, 103, 58, 32, 103, 122, 105, 112, 44, 32, 100, 101, 102, 108, 97, 116, 101,
                13, 10,
                85, 115, 101, 114, 45, 65, 103, 101, 110, 116, 58, 32, 120, 99, 116, 101, 115, 116, 47, 50, 49, 50, 53, 48, 32, 67, 70, 78, 101, 116, 119, 111, 114, 107, 47, 49, 51, 57, 56, 32, 68, 97, 114, 119, 105, 110, 47, 50, 50, 46, 49, 46, 48,
                13, 10,
                13, 10
            ])
            
            guard let message = HTTPRequest(data: data) else {
                XCTFail()
                return
            }
            
            XCTAssertNil(message.headers[.contentLength])
            XCTAssertEqual(message.headers[.userAgent], "xctest/21250 CFNetwork/1398 Darwin/22.1.0")
            XCTAssertEqual(message.headers.count, 6)
            XCTAssertEqual(message.uri, "/ping")
            XCTAssertEqual(HTTPRequest(data: message.data), message)
        }
    }
    
    func testResponseMessage() {
                
        do {
            let string = """
            HTTP/1.1 200 OK\r
            Date: Sun, 10 Oct 2010 23:26:07 GMT\r
            Server: Apache/2.2.8 (Ubuntu) mod_ssl/2.2.8 OpenSSL/0.9.8g\r
            Last-Modified: Sun, 26 Sep 2010 22:04:35 GMT\r
            ETag: "45b6-834-49130cc1182c0"\r
            Accept-Ranges: bytes\r
            Content-Length: 12\r
            Connection: close\r
            Content-Type: text/html\r
            \r
            Hello world!
            """
            
            guard let message = HTTPMessage(data: Data(string.utf8)) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(message.body, Data("Hello world!".utf8))
            XCTAssertEqual(message.headers[.date], "Sun, 10 Oct 2010 23:26:07 GMT")
            XCTAssertEqual(message.headers[.contentType], "text/html")
            XCTAssertEqual(message.headers.count, 8)
            XCTAssertEqual(message.head, .response(.init(version: .v1_1, code: .ok)))
            XCTAssertEqual(HTTPMessage(data: message.data), message)
        }
    }
    
    func testRequestHeader() {
        let string = #"GET /logo.gif HTTP/1.1"#
        guard let header = HTTPMessage.Header.Request(rawValue: string) else {
            XCTFail()
            return
        }
        XCTAssertEqual(header.method, .get)
        XCTAssertEqual(header.uri, "/logo.gif")
        XCTAssertEqual(header.version, .v1_1)
        XCTAssertEqual(HTTPMessage.Header(rawValue: string), .request(header))
    }
    
    func testResponseHeader() {
        let string = #"HTTP/1.1 200 OK"#
        guard let header = HTTPMessage.Header.Response(rawValue: string) else {
            XCTFail()
            return
        }
        XCTAssertEqual(header.version, .v1_1)
        XCTAssertEqual(header.code, .ok)
        XCTAssertEqual(header.status, header.code.reasonPhrase)
        XCTAssertEqual(HTTPMessage.Header(rawValue: string), .response(header))
    }
    
    func testServerPingPong() async throws {
        let port = UInt16.random(in: 8080 ..< 9000)
        var server: HTTPServer? = try await HTTPServer(configuration: .init(port: port), response: { (address, request) in
            if request.uri == "/ping", request.method == .get {
                return .init(code: .ok, body: Data("pong".utf8))
            } else {
                return .init(code: 404)
            }
        })
        assert(server != nil)
        let client = URLSession(configuration: .ephemeral)
        let serverURL  = URL(string: "http://localhost:\(port)")!
        
        let (pongData, pongResponse) = try await client.data(for: URLRequest(url: serverURL.appendingPathComponent("ping")))
        XCTAssertEqual((pongResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssertEqual(String(data: pongData, encoding: .utf8), "pong")
        
        //
        server = nil
        try await Task.sleep(nanoseconds: 100_000)
    }
    
    func testServerGetBlob() async throws {
        let port = UInt16.random(in: 8080 ..< 9000)
        let blob = Data(repeating: .random(in: .min ... .max), count: 1024 * .random(in: 1 ... 10))
        print("Blob:", blob.count)
        var server: HTTPServer? = try await HTTPServer(configuration: .init(port: port), response: { (address, request) in
            if request.uri == "/blob", request.method == .get {
                return request.body.isEmpty ? .init(code: .ok, body: blob) : .init(code: .badRequest)
            } else {
                return .init(code: 404)
            }
        })
        assert(server != nil)
        let client = URLSession(configuration: .ephemeral)
        let serverURL  = URL(string: "http://localhost:\(port)")!
        
        let (data, urlResponse) = try await client.data(for: URLRequest(url: serverURL.appendingPathComponent("blob")))
        XCTAssertEqual((urlResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssertEqual(data, blob)
        
        //
        server = nil
        try await Task.sleep(nanoseconds: 100_000)
    }
    
    func testServerPostBlob() async throws {
        let port = UInt16.random(in: 8080 ..< 9000)
        let blob = Data(repeating: .random(in: .min ... .max), count: 1024 * .random(in: 1 ... 10))
        print("Blob:", blob.count)
        var server: HTTPServer? = try await HTTPServer(configuration: .init(port: port), response: { (address, request) in
            if request.uri == "/blob", request.method == .post {
                XCTAssertEqual(request.headers[.contentLength], blob.count.description)
                XCTAssertEqual(request.body.count, blob.count)
                XCTAssertEqual(request.body, blob)
                return .init(code: request.body == blob ? .ok : .badRequest)
            }  else {
                return .init(code: 404)
            }
        })
        assert(server != nil)
        let client = URLSession(configuration: .ephemeral)
        let serverURL  = URL(string: "http://localhost:\(port)")!
        
        var request = URLRequest(url: serverURL.appendingPathComponent("blob"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = blob
        let (data, urlResponse) = try await client.data(for: request)
        XCTAssertEqual((urlResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssert(data.isEmpty)
        
        //
        server = nil
        try await Task.sleep(nanoseconds: 100_000)
    }
    
    func testServerGetLargeBlob() async throws {
        let port = UInt16.random(in: 8080 ..< 9000)
        let blob = Data(repeating: .random(in: .min ... .max), count: 1024 * 1024 * .random(in: 2 ... 4))
        print("Blob:", blob.count)
        var server: HTTPServer? = try await HTTPServer(configuration: .init(port: port), response: { (address, request) in
            if request.uri == "/blob", request.method == .get {
                return request.body.isEmpty ? .init(code: .ok, body: blob) : .init(code: .badRequest)
            } else {
                return .init(code: 404)
            }
        })
        assert(server != nil)
        let client = URLSession(configuration: .ephemeral)
        let serverURL  = URL(string: "http://localhost:\(port)")!
        
        let (data, urlResponse) = try await client.data(for: URLRequest(url: serverURL.appendingPathComponent("blob")))
        XCTAssertEqual((urlResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssertEqual(data, blob)
        
        //
        server = nil
        try await Task.sleep(nanoseconds: 100_000)
    }
    
    func testServerPostLargeBlob() async throws {
        let port = UInt16.random(in: 8080 ..< 9000)
        let blob = Data(repeating: .random(in: .min ... .max), count: 1024 * 1024 * .random(in: 2 ... 4))
        print("Blob:", blob.count)
        var server: HTTPServer? = try await HTTPServer(configuration: .init(port: port), response: { (address, request) in
            if request.uri == "/blob", request.method == .post {
                XCTAssertEqual(request.headers[.contentLength], blob.count.description)
                XCTAssertEqual(request.body.count, blob.count)
                XCTAssertEqual(request.body, blob)
                return .init(code: request.body == blob ? .ok : .badRequest)
            }  else {
                return .init(code: 404)
            }
        })
        assert(server != nil)
        let client = URLSession(configuration: .ephemeral)
        let serverURL  = URL(string: "http://localhost:\(port)")!
        
        var request = URLRequest(url: serverURL.appendingPathComponent("blob"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = blob
        let (data, urlResponse) = try await client.data(for: request)
        XCTAssertEqual((urlResponse as! HTTPURLResponse).statusCode, 200)
        XCTAssert(data.isEmpty)
        
        //
        server = nil
        try await Task.sleep(nanoseconds: 100_000)
    }
}
