
/*
 * @nixzhu (zhuhongxu@gmail.com)
 */

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

func one<A>(of parsers: [Parser<A>]) -> Parser<A> {
    return { stream in
        for parser in parsers {
            if let x = parser(stream) {
                return x
            }
        }
        return nil
    }
}

func or<A>(_ leftParser: @escaping Parser<A>, _ rightParser: @escaping Parser<A>) -> Parser<A> {
    return { stream in
        return leftParser(stream) ?? rightParser(stream)
    }
}

func between<A, B, C>(_ a: @escaping Parser<A>, _ b: @escaping Parser<B>, _ c: @escaping Parser<C>) -> Parser<B> {
    return { stream in
        guard let (_, remainder1) = a(stream) else { return nil }
        guard let (result2, remainder2) = b(remainder1) else { return nil }
        guard let (_, remainder3) = c(remainder2) else { return nil }
        return (result2, remainder3)
    }
}

func eatLeft<A, B>(_ left: @escaping Parser<A>, _ right: @escaping Parser<B>) -> Parser<B> {
    return { stream in
        guard let (_, remainder1) = left(stream) else { return nil }
        guard let (result2, remainder2) = right(remainder1) else { return nil }
        return (result2, remainder2)
    }
}

func eatRight<A, B>(_ left: @escaping Parser<A>, _ right: @escaping Parser<B>) -> Parser<A> {
    return { stream in
        guard let (result1, remainder1) = left(stream) else { return nil }
        guard let (_, remainder2) = right(remainder1) else { return nil }
        return (result1, remainder2)
    }
}

enum Token {
    case plainText(string: String)
    case beginBoldTag
    case endBoldTag
    case beginItalicTag
    case endItalicTag
    case beginParagraphTag
    case endParagraphTag
    case beginAnchorTag(href: String)
    case endAnchorTag
}

let spaces: Parser<String> = {
    let space = one(of: [
        character(" "),
        character("\0"),
        character("\t"),
        character("\r"),
        character("\n"),
        ]
    )
    let spaceString = map(space) { String($0) }
    return map(many(or(spaceString, word("\r\n")))) { $0.joined() }
}()
let plainText: Parser<Token> = {
    let letter = satisfy({ $0 != "<" && $0 != ">" })
    let string = map(many1(letter)) { String($0) }
    return map(string) { .plainText(string: $0) }
}()
let beginBoldTag: Parser<Token> = map(word("<b>")) { _ in .beginBoldTag }
let endBoldTag: Parser<Token> = map(word("</b>")) { _ in .endBoldTag }
let beginItalicTag: Parser<Token> = map(word("<i>")) { _ in .beginItalicTag }
let endItalicTag: Parser<Token> = map(word("</i>")) { _ in .endItalicTag }
let beginParagraphTag: Parser<Token> = map(word("<p>")) { _ in .beginParagraphTag }
let endParagraphTag: Parser<Token> = map(word("</p>")) { _ in .endParagraphTag }
let beginAnchorTag: Parser<Token> = {
    let head = eatRight(word("<a"), spaces)
    let quotedString: Parser<String> = {
        let unescapedCharacter = satisfy({ $0 != "\\" && $0 != "\"" })
        let escapedCharacter = one(of: [
            map(word("\\\"")) { _ in Character("\"") },
            map(word("\\\\")) { _ in Character("\\") },
            map(word("\\/")) { _ in Character("/") },
            map(word("\\n")) { _ in Character("\n") },
            map(word("\\r")) { _ in Character("\r") },
            map(word("\\t")) { _ in Character("\t") },
            ]
        )
        let letter = one(of: [unescapedCharacter, escapedCharacter])
        let _string = map(many(letter)) { String($0) }
        let quote = character("\"")
        return between(quote, _string, quote)
    }()
    let href = eatLeft(word("href="), quotedString)
    let tail = eatLeft(spaces, word(">"))
    return map(between(head, href, tail)) { .beginAnchorTag(href: $0) }
}()
let endAnchorTag: Parser<Token> = map(word("</a>")) { _ in .endAnchorTag }

func tokenize(_ htmlString: String) -> [Token] {
    var tokens: [Token] = []
    var remainder = htmlString.characters
    let parsers = [
        plainText,
        beginBoldTag,
        endBoldTag,
        beginItalicTag,
        endItalicTag,
        beginParagraphTag,
        endParagraphTag,
        beginAnchorTag,
        endAnchorTag
    ]
    while true {
        guard !remainder.isEmpty else { break }
        let remainderLength = remainder.count
        for parser in parsers {
            if let (token, newRemainder) = parser(remainder) {
                tokens.append(token)
                remainder = newRemainder
            }
        }
        let newRemainderLength = remainder.count
        guard newRemainderLength < remainderLength else {
            break
        }
    }
    return tokens
}

indirect enum Value {
    case plainText(string: String)
    case boldTag(value: Value)
    case italicTag(value: Value)
    case paragraphTag(value: Value)
    case anchorTag(href: String, value: Value)
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
        case .beginParagraphTag:
            stack.push(.token(.beginParagraphTag))
        case .endParagraphTag:
            var elements: [Element] = []
            while let element = stack.pop() {
                if case .token(let value) = element {
                    if case .beginParagraphTag = value {
                        break
                    }
                }
                elements.append(element)
            }
            if elements.count == 1 {
                let element = elements[0]
                if let value = element.value {
                    stack.push(.value(.paragraphTag(value: value)))
                } else {
                    print("todo: \(elements)")
                }
            } else {
                stack.push(.value(.paragraphTag(value: .sequence(values: elements.reversed().map({ $0.value }).flatMap({ $0 })))))
            }
        case .beginAnchorTag(let href):
            stack.push(.token(.beginAnchorTag(href: href)))
        case .endAnchorTag:
            var elements: [Element] = []
            var href = ""
            while let element = stack.pop() {
                if case .token(let value) = element {
                    if case .beginAnchorTag(let _href) = value {
                        href = _href
                        break
                    }
                }
                elements.append(element)
            }
            if elements.count == 1 {
                let element = elements[0]
                if let value = element.value {
                    stack.push(.value(.anchorTag(href: href, value: value)))
                } else {
                    print("todo: \(elements)")
                }
            } else {
                stack.push(.value(.anchorTag(href: href, value: .sequence(values: elements.reversed().map({ $0.value }).flatMap({ $0 })))))
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
let htmlString = "<p>hello <b>world</b><i>!</i></p><p><b>OK</b></p><a href=\"https://www.apple.com\">apple.<b>com</b></a>"
let tokens = tokenize(htmlString)
print("tokens: \(tokens)")
let value = parse(tokens)
print("~~~~~~~~~~~~~~~~~~~~~~~~~")
print(value)
