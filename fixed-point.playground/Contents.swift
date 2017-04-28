
//: # 不动点
//: 数`x`称为函数`f`的不动点，如果`x`满足方程`f(x)=x`

import Foundation

func fixedPoint(of function: @escaping (Double) -> Double, withFirstGuess firstGuess: Double) -> Double {
    let tolerance = 0.00001
    func closeEnough(_ value: Double, _ guess: Double) -> Bool {
        return abs(value - guess) < tolerance
    }
    func tryGuess(_ guess: Double) -> Double {
        let next = function(guess)
        if closeEnough(next, guess) {
            return next
        } else {
            return tryGuess(next)
        }
    }
    return tryGuess(firstGuess)
}

//: 计算函数`cos`的不动点（你可以找个计算器，设置为弧度模式，然后反复按cos键）
fixedPoint(of: cos, withFirstGuess: 1)

//: 计算某个数`x`的平方根，就是要找到一个`y`，使得`y*y=x`，这一等式的等价形式是`y=x/y`
/*
func _sqrt(of x: Double) -> Double {
    return fixedPoint(of: { y in x / y }, withFirstGuess: 1)
}

_sqrt(of: 2)
 */

//: 上面的搜寻并不会收敛，因为猜测的震荡太剧烈了，一种可行的办法是求两次猜测的平均
func sqrt(of x: Double) -> Double {
    return fixedPoint(of: { y in (y + x / y) / 2 }, withFirstGuess: 1)
}

sqrt(of: 2)
sqrt(of: 4)
