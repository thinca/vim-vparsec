" This is a sample for vparsec.vim
function! Calculator(input)
  let conv = {}
  function! conv.expr(res)
    " res = [firstToken, [op, rhs]*]
    let [left, rest] = a:res
    for [op, right] in rest
      execute printf('let left = left %s right', op)
    endfor
    return left
  endfunction
  function! conv.term(res)
      return str2float(a:res)
  endfunction

  let p = vparsec#parsers()

  let expr = p.lazy().named('expr')

  let number = p.regex('\v[+-]?\d+%(\.\d+%(e[+-]?\d+)?)?').named('number')
  let token = p.or('+', '-', '*', '/', '(', ')', number)
  let whitespace = p.regex('\s*')
  let lexer = token.lexer(whitespace)

  let s = vparsec#scanners()

  let tnumber = s.toParser(number)
  let term = s.or(tnumber.map(conv.term), s.seq('(', expr, ')').at(1)).named('term')
  let mul = term.next(s.seq(s.or('*', '/'), term).many()).map(conv.expr).named('mul')
  let add = mul.next(s.seq(s.or('+', '-'), mul).many()).map(conv.expr).named('add')
  call expr.set(add)

  let result = lexer.parse(a:input)
  if !result.successful
    return result
  endif
  let result = expr.phrase().parse(result.result)
  return result.successful ? result.result : result.toString()
endfunction

echo Calculator('(2 + 4.2) * 8 + 1.3 - 2 * 3 + (3.1e2 / 2)')
