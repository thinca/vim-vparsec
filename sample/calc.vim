" This is a sample for vparsec.vim

function! s:build_calculator()
  let p = vparsec#parsers()

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

  let number = p.regex('\v[+-]?\d+%(\.\d+%(e[+-]?\d+)?)?').named('number')
  let expr = p.lazy().named('expr')
  let term = p.or(number.map(conv.term), p.seq('(', expr, ')').at(1)).named('term')
  let mul = term.next(p.seq(p.or('*', '/'), term).many()).map(conv.expr).named('mul')
  let add = mul.next(p.seq(p.or('+', '-'), mul).many()).map(conv.expr).named('add')
  call expr.set(add)

  return expr.phrase()
endfunction

function! s:run_sample(calculator, input)
  let result = a:calculator.parse(a:input)
  if !result.successful
    return result.toString()
  endif
  return result.result
endfunction

echo s:run_sample(s:build_calculator(), '(2+4.2)*8+1.3-2*3+(3.1e2/2)')
