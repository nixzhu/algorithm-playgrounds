/*
    @nixzhu (zhuhongxu@gmail.com)
    Welcome to contact me with iMessage: nixzhu@icloud.com
 */

enum Value {
    case null
    case bool(Bool)
    enum Number {
        case int(Int)
        case double(Double)
    }
    case number(Number)
    case string(String)
    indirect case object([String: Value])
    indirect case array([Value])
}

typealias Stream = String.CharacterView
typealias Parser<A> = (Stream) -> (A, Stream)?

func test<A>(_ parser: Parser<A>, _ input: String) -> (A, String)? {
    guard let (result, remainder) = parser(input.characters) else { return nil }
    return (result, String(remainder))
}

let a: Parser<Character> = { stream in
    guard let firstCharacter = stream.first, firstCharacter == "a" else { return nil }
    return (firstCharacter, stream.dropFirst())
}

test(a, "abc")

a("abc".characters)

func character(_ character: Character) -> Parser<Character> {
    let parser: Parser<Character> = { stream in
        guard let firstCharacter = stream.first, firstCharacter == character else { return nil }
        return (firstCharacter, stream.dropFirst())
    }
    return parser
}

let b = character("b")
test(b, "bcd")

func word(_ string: String) -> Parser<String> {
    let parsers = string.characters.map({ character($0) })
    let parser: Parser<String> = { stream in
        var characters: [Character] = []
        var remainder = stream
        for parser in parsers {
            guard let (character, newRemainder) = parser(remainder) else { return nil }
            characters.append(character)
            remainder = newRemainder
        }
        return (String(characters), remainder)
    }
    return parser
}

//let null = word("null")
//test(null, "null!")

func map<A, B>(_ parser: @escaping Parser<A>, _ transform: @escaping (A) -> B) -> Parser<B> {
    let newParser: Parser<B> = { stream in
        guard let (result, remainder) = parser(stream) else { return nil }
        return (transform(result), remainder)
    }
    return newParser
}

//let null = map(word("null"), { _ in Value.null })
//test(null, "null!")

let null = map(word("null")) { _ in Value.null }
test(null, "null!")

let `true` = map(word("true")) { _ in true }
let `false` = map(word("false")) { _ in false }
test(`true`, "true?")
test(`false`, "false?")

func or<A>(_ leftParser: @escaping Parser<A>, _ rightParser: @escaping Parser<A>) -> Parser<A> {
    let parser: Parser<A> = { stream in
        return leftParser(stream) ?? rightParser(stream)
    }
    return parser
}

let bool = map(or(`true`, `false`)) { bool in Value.bool(bool) }
test(bool, "true?")
test(bool, "false?")

let digitCharacters = "0123456789.-".characters.map { $0 }
let digitParsers = digitCharacters.map { character($0) }

func one<A>(of parsers: [Parser<A>]) -> Parser<A> {
    let parser: Parser<A> = { stream in
        for parser in parsers {
            if let x = parser(stream) {
                return x
            }
        }
        return nil
    }
    return parser
}

let digit = one(of: digitParsers)
test(digit, "123")

func many<A>(_ parser: @escaping Parser<A>) -> Parser<[A]> {
    let parser: Parser<[A]> = { stream in
        var result = [A]()
        var remainder = stream
        while let (element, newRemainder) = parser(remainder) {
            result.append(element)
            remainder = newRemainder
        }
        return (result, remainder)
    }
    return parser
}

func many1<A>(_ parser: @escaping Parser<A>) -> Parser<[A]> {
    let parser: Parser<[A]> = { stream in
        guard let (element, remainder1) = parser(stream) else { return nil }
        if let (array, remainder2) = many(parser)(remainder1) {
            return ([element] + array, remainder2)
        } else {
            return ([element], remainder1)
        }
    }
    return parser
}

let number: Parser<Value> = map(many1(digit)) {
    let numberString = String($0)
    if let int = Int(numberString) {
        return Value.number(.int(int))
    } else {
        let double = Double(numberString)!
        return Value.number(.double(double))
    }
}

test(number, "-123.34")
    .flatMap({ print($0) })

func between<A, B, C>(_ a: @escaping Parser<A>, _ b: @escaping Parser<B>, _ c: @escaping Parser<C>) -> Parser<B> {
    let parser: Parser<B> = { stream in
        guard let (_, remainder1) = a(stream) else { return nil }
        guard let (result2, remainder2) = b(remainder1) else { return nil }
        guard let (_, remainder3) = c(remainder2) else { return nil }
        return (result2, remainder3)
    }
    return parser
}

let quotedString: Parser<String> = {
    let lowercaseParsers = "abcdefghijklmnopqrstuvwxyz".characters.map({ character($0) })
    let uppercaseParsers = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".characters.map({ character($0) })
    let otherParsers = " \t_-".characters.map({ character($0) }) // TODO: more
    let letter = one(of: lowercaseParsers + uppercaseParsers + otherParsers)
    let _string = map(many1(letter)) { String($0) }
    let quote = character("\"")
    return between(quote, _string, quote)
}()

let string = map(quotedString) { Value.string($0) }
test(string, "\"name\"")

var _value: Parser<Value>?
let value: Parser<Value> = { stream in
    if let parser = _value {
        return parser(stream)
    }
    return nil
}

func and<A, B>(_ left: @escaping Parser<A>, _ right: @escaping Parser<B>) -> Parser<(A, B)> {
    return { stream in
        guard let (result1, remainder1) = left(stream) else { return nil }
        guard let (result2, remainder2) = right(remainder1) else { return nil }
        return ((result1, result2), remainder2)
    }
}

func eatRight<A, B>(_ left: @escaping Parser<A>, _ right: @escaping Parser<B>) -> Parser<A> {
    return { stream in
        guard let (result1, remainder1) = left(stream) else { return nil }
        guard let (_, remainder2) = right(remainder1) else { return nil }
        return (result1, remainder2)
    }
}

func list<A, B>(_ parser: @escaping Parser<A>, _ separator: @escaping Parser<B>) -> Parser<[A]> {
    return { stream in
        let separatorThenParser = and(separator, parser)
        let parser = and(parser, many(separatorThenParser))
        guard let (result, remainder) = parser(stream) else { return nil }
        let finalResult = [result.0] + result.1.map({ $0.1 })
        return (finalResult, remainder)
    }
}

let object: Parser<Value> = {
    let beginObject = character("{")
    let endObject = character("}")
    let colon = character(":")
    let comma = character(",")
    let keyValue = and(eatRight(quotedString, colon), value)
    let keyValues = list(keyValue, comma)
    return map(between(beginObject, keyValues, endObject)) {
        var dictionary: [String: Value] = [:]
        for (key, value) in $0 {
            dictionary[key] = value
        }
        return Value.object(dictionary)
    }
}()

test(object, "{\"name\":\"NIX\",\"age\":18}")

let array: Parser<Value> = {
    let beginArray = character("[")
    let endArray = character("]")
    let comma = character(",")
    let values = list(value, comma)
    return map(between(beginArray, values, endArray)) { Value.array($0) }
}()

_value = one(of: [null, bool, number, string, array, object])

test(object, "{\"name\":\"NIX\",\"age\":18}")
    .flatMap({ print($0) })

let jsonString = "{\"name\":\"NIX\",\"age\":18,\"detail\":{\"skills\":[\"Swift on iOS\",\"C on Linux\"],\"projects\":[{\"name\":\"coolie\",\"intro\":\"Generate models from a JSON file\"},{\"name\":\"parser\",\"intro\":null}]}}"
test(value, jsonString)
    .flatMap({ print($0) })

let jsonString2 = "[{\"name\":\"coolie\",\"intro\":\"Generate models from a JSON file\"},{\"name\":\"parser\",\"intro\":null}]"
test(value, jsonString2)
    .flatMap({ print($0) })
