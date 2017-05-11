
/*
 * @nixzhu (zhuhongxu@gmail.com)
 */

enum Token {
    case plainText(string: String)
    case beginBoldTag
    case endBoldTag
    case beginItalicTag
    case endItalicTag
}

typealias Stream = String.CharacterView
typealias Parser<A> = (Stream) -> (A, Stream)?

func character(_ character: Character) -> Parser<Character> {
    return { stream in
        guard let firstCharacter = stream.first, firstCharacter == character else { return nil }
        return (firstCharacter, stream.dropFirst())
    }
}

func word(_ string: String) -> Parser<String> {
    let parsers = string.characters.map({ character($0) })
    return { stream in
        var characters: [Character] = []
        var remainder = stream
        for parser in parsers {
            guard let (character, newRemainder) = parser(remainder) else { return nil }
            characters.append(character)
            remainder = newRemainder
        }
        return (String(characters), remainder)
    }
}

func satisfy(_ condition: @escaping (Character) -> Bool) -> Parser<Character> {
    return { stream in
        guard let firstCharacter = stream.first, condition(firstCharacter) else { return nil }
        return (firstCharacter, stream.dropFirst())
    }
}

func many<A>(_ parser: @escaping Parser<A>) -> Parser<[A]> {
    return { stream in
        var result = [A]()
        var remainder = stream
        while let (element, newRemainder) = parser(remainder) {
            result.append(element)
            if remainder.count == newRemainder.count {
                break
            }
            remainder = newRemainder
        }
        return (result, remainder)
    }
}

func many1<A>(_ parser: @escaping Parser<A>) -> Parser<[A]> {
    return { stream in
        guard let (element, remainder1) = parser(stream) else { return nil }
        if let (array, remainder2) = many(parser)(remainder1) {
            return ([element] + array, remainder2)
        } else {
            return ([element], remainder1)
        }
    }
}

func map<A, B>(_ parser: @escaping Parser<A>, _ transform: @escaping (A) -> B) -> Parser<B> {
    return { stream in
        guard let (result, remainder) = parser(stream) else { return nil }
        return (transform(result), remainder)
    }
}

let plainText: Parser<Token> = {
    let letter = satisfy({ $0 != "<" && $0 != ">" })
    let string = map(many1(letter)) { String($0) }
    return map(string) { .plainText(string: $0) }
}()
let beginBoldTag: Parser<Token> = map(word("<b>")) { _ in .beginBoldTag }
let endBoldTag: Parser<Token> = map(word("</b>")) { _ in .endBoldTag }
let beginItalicTag: Parser<Token> = map(word("<i>")) { _ in .beginItalicTag }
let endItalicTag: Parser<Token> = map(word("</i>")) { _ in .endItalicTag }

func tokenize(_ htmlString: String) -> [Token] {
    var tokens: [Token] = []
    var remainder = htmlString.characters
    while true {
        if let (token, newRemainder) = plainText(remainder) {
            tokens.append(token)
            remainder = newRemainder
        }
        if let (token, newRemainder) = beginBoldTag(remainder) {
            tokens.append(token)
            remainder = newRemainder
        }
        if let (token, newRemainder) = endBoldTag(remainder) {
            tokens.append(token)
            remainder = newRemainder
        }
        if let (token, newRemainder) = beginItalicTag(remainder) {
            tokens.append(token)
            remainder = newRemainder
        }
        if let (token, newRemainder) = endItalicTag(remainder) {
            tokens.append(token)
            remainder = newRemainder
        }
        if remainder.isEmpty {
            break
        }
    }
    return tokens
}

indirect enum Value {
    case plainText(string: String)
    case boldTag(value: Value)
    case italicTag(value: Value)
    case sequence(values: [Value])
}

enum Element {
    case token(Token)
    case value(Value)

    var value: Value? {
        switch self {
        case .token(let token):
            switch token {
            case .plainText(let string):
                return .plainText(string: string)
            default:
                return nil
            }
        case .value(let value):
            return value
        }
    }
}

class Stack {
    var array: [Element] = []

    func push(_ element: Element) {
        array.append(element)
    }

    func pop() -> Element? {
        guard !array.isEmpty else { return nil }
        return array.removeLast()
    }
}

func parse(_ tokens: [Token]) -> Value {
    let stack = Stack()
    var next = 0
    func _parse() -> Bool {
        guard next < tokens.count else {
            return false
        }
        let token = tokens[next]
        switch token {
        case .plainText(let string):
            stack.push(.value(.plainText(string: string)))
        case .beginBoldTag:
            stack.push(.token(.beginBoldTag))
        case .endBoldTag:
            var elements: [Element] = []
            while let element = stack.pop() {
                if case .token(let value) = element {
                    if case .beginBoldTag = value {
                        break
                    }
                }
                elements.append(element)
            }
            if elements.count == 1 {
                let element = elements[0]
                if let value = element.value {
                    stack.push(.value(.boldTag(value: value)))
                } else {
                    print("todo: \(elements)")
                }
            } else {
                stack.push(.value(.boldTag(value: .sequence(values: elements.reversed().map({ $0.value }).flatMap({ $0 })))))
            }
        case .beginItalicTag:
            stack.push(.token(.beginItalicTag))
        case .endItalicTag:
            var elements: [Element] = []
            while let element = stack.pop() {
                if case .token(let value) = element {
                    if case .beginItalicTag = value {
                        break
                    }
                }
                elements.append(element)
            }
            if elements.count == 1 {
                let element = elements[0]
                if let value = element.value {
                    stack.push(.value(.italicTag(value: value)))
                } else {
                    print("todo: \(elements)")
                }
            } else {
                stack.push(.value(.italicTag(value: .sequence(values: elements.reversed().map({ $0.value }).flatMap({ $0 })))))
            }
        }
        return true
    }
    while true {
        if !_parse() {
            break
        }
        print("=============================")
        for e in stack.array {
            print("e: \(e)")
        }
        next += 1
    }
    print("#############################")
    for e in stack.array {
        print("e: \(e)")
    }
    return .sequence(values: stack.array.map({ $0.value }).flatMap({ $0 }))
}

//let htmlString = "hello<b>world<i>!</i></b>"
let htmlString = "<b>hello<b>world<i>!</i></b></b>"
let tokens = tokenize(htmlString)
print("tokens: \(tokens)")
let value = parse(tokens)
print("~~~~~~~~~~~~~~~~~~~~~~~~~")
print(value)
