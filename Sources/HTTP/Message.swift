//
//  Message.swift
//  
//
//  Created by Alsey Coleman Miller on 10/2/22.
//

import Foundation

/// HTTP Message
internal struct HTTPMessage: Equatable, Hashable {
    
    public var head: Header
    
    public var headers: [HTTPHeader: String]
    
    public var body: Data
}

extension HTTPMessage {
    
    init?(data: Data) {
        var decoder = Decoder(data: data)
        switch decoder.read() {
        case .failure:
            return nil
        case let .success(value):
            self = value
        }
    }
    
    var data: Data {
        var data = Data()
        data.append(contentsOf: head.rawValue.utf8)
        data.append(contentsOf: HTTPMessage.Decoder.lineSeparator.utf8)
        for (header, value) in headers.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            data.append(contentsOf: header.rawValue.utf8)
            data.append(contentsOf: ": ".utf8)
            data.append(contentsOf: value.utf8)
            data.append(contentsOf: HTTPMessage.Decoder.lineSeparator.utf8)
        }
        data.append(contentsOf: HTTPMessage.Decoder.lineSeparator.utf8)
        assert(data.suffix(4) == HTTPMessage.Decoder.headerSuffixData)
        data.append(body)
        return data
    }
}

// MARK: - Decoder

extension HTTPMessage {
    
    struct Decoder {
        
        enum Error: Swift.Error {
            case endOfStream
            case invalidCharacter
            case invalidHeaderLine
        }
        
        let data: Data
        
        private(set) var index = 0
        
        var isEnd: Bool {
            index >= data.count
        }
        
        mutating func read() -> Result<HTTPMessage, Decoder.Error> {
            assert(isEnd == false)
            switch readHead() {
            case let .failure(error):
                return .failure(error)
            case let .success(head):
                switch readHeaders() {
                case let .failure(error):
                    return .failure(error)
                case let .success(headers):
                    let body = isEnd ? Data() : data.suffix(from: index)
                    index = data.count
                    assert(isEnd)
                    let message = HTTPMessage(
                        head: head,
                        headers: headers.reduce(into: [HTTPHeader: String](), { $0[$1.0] = $1.1 }),
                        body: body
                    )
                    return .success(message)
                }
            }
        }
        
        private mutating func readHeaders() -> Result<[(HTTPHeader, String)], Decoder.Error> {
            var headers = [(HTTPHeader, String)]()
            repeat {
                let lineResult = readLine()
                switch lineResult {
                case let .failure(failure):
                    return .failure(failure)
                case let .success(line):
                    guard line.isEmpty == false else {
                        return .success(headers)
                    }
                    guard line.contains(Self.headerSeparator) else {
                        return .failure(.invalidHeaderLine)
                    }
                    // parse line
                    let headerComponents = line.split(separator: Self.headerSeparator, maxSplits: 1, omittingEmptySubsequences: true)
                    guard let name = headerComponents.first.map(String.init), var value = headerComponents.last else {
                        return .failure(.invalidHeaderLine)
                    }
                    // remove whitespace prefix
                    if value.first == " " {
                        value.removeFirst()
                    }
                    headers.append((
                        HTTPHeader(rawValue: name),
                        String(value)
                    ))
                }
            } while true
        }
        
        private mutating func readByte() -> UInt8? {
            guard index < data.count else {
                return nil
            }
            let byte = data[index]
            index += 1
            return byte
        }
        
        private mutating func readLine() -> Result<String, Decoder.Error> {
            let start = index
            var lastCR: Int?
            while let byte = readByte() {
                if byte == Self.cr {
                    lastCR = index - 1
                    continue
                }
                guard byte == Self.nl,
                    let indexCR = lastCR,
                    indexCR == index - 2 else {
                    continue
                }
                let bytes = data[start ..< indexCR] // TODO: Use no copy instance
                guard let string = String(data: bytes, encoding: .utf8) else {
                    return .failure(.invalidCharacter)
                }
                return .success(string)
            }
            return .failure(.endOfStream) // end of data
        }
        
        private mutating func readHead() -> Result<HTTPMessage.Header, Decoder.Error> {
            readLine()
                .flatMap {
                    HTTPMessage.Header($0).map { .success($0) } ?? .failure(.invalidCharacter)
                }
        }
    }
}

extension HTTPMessage.Decoder {
    
    /// "\n"
    static var nl: UInt8 { 10 }
    
    /// "\r"
    static var cr: UInt8 { 13 }
    
    static var headerSeparator: Character { ":" }
    
    static var lineSeparator: String { "\r\n" }
    
    static var headerSuffix: String { "\r\n\r\n" }
    
    static let headerSuffixData = Data(headerSuffix.utf8)
}
