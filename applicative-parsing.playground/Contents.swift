
/*
 * @nixzhu (zhuhongxu@gmail.com)
 * ref: https://www.youtube.com/watch?v=I-YW4sNkX6I
 */


struct Parameter<A> {
    let type: String
    let parse: (Any) -> A?
}

extension Parameter {
    func check(reason: String, condition: @escaping (A) -> Bool) -> Parameter<A> {
        return Parameter(type: "\(type), \(reason)") { value in
            guard let result = self.parse(value) else { return nil }
            guard condition(result) else { return nil }
            return result
        }
    }
}

struct NamedParameter<A> {
    let name: String
    let type: String
    let parse: (JSONDictionary) -> A?
}

extension NamedParameter {
    init(name: String, parameter: Parameter<A>) {
        self.name = name
        self.type = parameter.type
        self.parse = { dictionary in
            guard let value = dictionary[name] else { return nil }
            return parameter.parse(value)
        }
    }

    var optional: NamedParameter<A?> {
        return NamedParameter<A?>(name: name, type: "\(type), optional") { dictionary in
            guard dictionary[self.name] != nil else { return .some(nil) }
            return self.parse(dictionary)
        }
    }
}

typealias JSONDictionary = [String: Any]

struct Parser<A> {
    let info: [String: String]
    let parse: (JSONDictionary) -> A?
}

extension Parser {
    init(_ np: NamedParameter<A>) {
        self.info = [np.name: np.type]
        self.parse = np.parse
    }

    init(pure value: A) {
        self.info = [:]
        self.parse = { _ in value }
    }
}

infix operator <*>: Apply
precedencegroup Apply {
    associativity: left
}

func <*><A, B>(lhs: Parser<(A) -> B>, rhs: NamedParameter<A>) -> Parser<B> {
    var info = lhs.info
    info[rhs.name] = rhs.type
    return Parser<B>(info: info) { dictionary in
        guard let f = lhs.parse(dictionary) else { return nil }
        guard let x = rhs.parse(dictionary) else { return nil }
        return f(x)
    }
}

struct User {
    let id: Int
    let name: String
    let address: String?
}

let int = Parameter<Int>(type: "Int") { $0 as? Int }
let string = Parameter<String>(type: "String") { $0 as? String }

let id = NamedParameter(name: "id", parameter: int.check(reason: ">0", condition: { $0 > 0 }))
let name = NamedParameter(name: "name", parameter: string)
let address = NamedParameter(name: "address", parameter: string).optional

let makeUser = { id in { name in { address in User(id: id, name: name, address: address) } } }
let userParser = Parser(pure: makeUser) <*> id <*> name <*> address

print(userParser.info)
dump(userParser.parse([:]))
dump(userParser.parse(["id": 0, "name": "NIX"]))
dump(userParser.parse(["id": 1, "name": "NIX"]))
dump(userParser.parse(["id": 2, "name": "NIX", "address": "CandyStar"]))
