" This is a sample for vparsec.vim
function! Funcaller(input)
  call vparsec#import(l:)

  let conv = {}
  function! conv.expr(res)
    " res = [firstToken, [op, rhs]*]
    let [ident, left_parenthesis, arg, right_parenthesis] = a:res
    execute printf('%s(%s)', ident, arg)
  endfunction

  let p = Parsers.new()

  let expr = p.lazy().named('expr')

  let ident = p.regex('\<\h\w*').named('ident')
  let string = p.regex('\%^"\w*"').named('string')
  let token = p.or('(', ')', string, ident)
  let whitespace = p.regex('\s*')
  let lexer = token.lexer(whitespace)

  let s = Scanners.new()
  let funcall = (s.seq(ident, '(', string, ')')).map(conv.expr)
  call expr.set(funcall)

  let result = lexer.parse(a:input)
  if !result.successful
    return result
  endif
  let result = expr.phrase().parse(result.result)
  return result.successful ? result.result : result.toString()
endfunction

call Funcaller('echo ("HelloWorld")')
