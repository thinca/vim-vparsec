" Parser Combinator for Vim script.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

let s:null = {}

let s:Object = {}

function! s:Object.new(...)
  let obj = copy(self)
  let o = obj
  while has_key(o, 'super')
    call extend(obj, o.super, 'keep')
    let o = o.super
  endwhile
  call call(obj.initialize, a:000, obj)
  return obj
endfunction
function! s:Object.initialize(...)
endfunction
function! s:Object.clone()
  return copy(self)
endfunction
function! s:Object.extend()
  return extend({'super': self}, self, 'keep')
endfunction
function! s:Object.toString()
  return '[Object]'
endfunction

function! s:toString(obj)
  return type(a:obj) == type({}) && has_key(a:obj, 'toString')
  \   && type(a:obj.toString) == type(function('function')) ?
  \      a:obj.toString() : string(a:obj)
endfunction





let s:Reader = s:Object.extend()

let s:StringReader = s:Reader.extend()
function! s:StringReader.initialize(str, ...)
  let self.source = a:str
  let self.offset = a:0 ? a:1 : 0
endfunction
function! s:StringReader.atEnd()
  return strlen(self.source) <= self.offset
endfunction
function! s:StringReader.first()
  return self.source[self.offset]
endfunction
function! s:StringReader.rest()
  return self.atEnd() ? self : s:StringReader.new(self.source, self.offset + 1)
endfunction
function! s:StringReader.toString()
  return printf('StringReader(%s, %s)', self.source, self.offset)
endfunction



let s:Scanner = s:Reader.extend()
function! s:Scanner.initialize(in, token, ...)
  let self.in = type(a:in) == type('') ? s:StringReader.new(a:in) : a:in
  let self.token = a:token
  let self.whitespace = a:0 ? a:1 : s:Parsers.regex('\s*')
  let self.offset = self.in.offset
endfunction
function! s:Scanner.atEnd()
  call self._t()
  return in.atEnd()  " FIXME: end of whitespace
endfunction
function! s:Scanner.first()
  call self._t()
  return self.tok
endfunction
function! s:Scanner.rest()
  call self._t()
  return s:Scanner.new(self.nextin, self.token)
endfunction
function! s:Scanner._t()
  if has_key(self, 'tok')
    return
  endif
  let res1 = self.whitespace.parse(self.in)
  if res1.successful
    let res2 = self.token.parse(res1.next)
    if res2.successful
      let self.tok = res2.result
      let self.nextin = self.next
      return
    endif
  endif
  let self.tok = []  " FIXME: error token
  let self.nextin = self.in
endfunction
function! s:Scanner.toString()
  return printf('Scanner(%s, %s, %s)', self.in.toString(),
  \             self.token.toString(), self.whitespace.toString())
endfunction




let s:ParseResult = s:Object.extend()
function! s:ParseResult.success(result, next)
  let res = s:ParseResult.new()
  let res.successful = 1
  let res.result = a:result
  let res.next = a:next
  return res
endfunction
function! s:ParseResult.failure(mes, next)
  let res = s:ParseResult.new()
  let res.successful = 0
  let res.message = a:mes
  let res.next = a:next
  return res
endfunction
function! s:ParseResult.toString()
  return self.successful
  \ ? 'Success(' . s:toString(self.result) . ', ' . s:toString(self.next) . ')'
  \ : 'Failure(' . self.message . ', ' . s:toString(self.next) . ')'
endfunction




let s:Parser = s:Object.extend()
function! s:Parser.parse(input)
  let input = self.asReader(a:input)
  return self.apply(input)
endfunction
function! s:Parser.apply(input)
  return s:ParseResult.failure('abstract parser', input)
endfunction
function! s:Parser.asReader(input)
  if type(a:input) == type('')
    return s:StringReader.new(a:input)
  endif
  return a:input
endfunction
function! s:Parser.named(name)
  let self.name = a:name
  return self
endfunction
function! s:Parser.toString()
  return self.name
endfunction



" ----------------------------------------------------------------------------
" Parsers
let s:Parsers = s:Object.extend()



let s:eof = s:Parser.extend().named('eof')
function! s:eof.apply(input)
  return a:input.atEnd()
  \ ? s:ParseResult.success(s:null, a:input)
  \ : s:ParseResult.failure('end of input expected', a:input)
endfunction
function! s:eof.toString()
  return '[eof]'
endfunction

function! s:Parsers.eof(...)
  return s:eof
endfunction



let s:seq = s:Parser.extend().named('seq')
function! s:seq.initialize(parsers)
  let self.parsers = a:parsers
endfunction
function! s:seq.apply(input)
  let input = a:input
  let res = []
  for p in self.parsers
    let result = p.parse(input)
    if !result.successful
      return result
    endif
    let input = result.next
    call add(res, result.result)
  endfor
  if has_key(self, 'point')
    if has_key(self, 'end')
      let res = res[self.point : self.end]
    else
      let res1 = res[self.point]
      unlet res
      let res = res1
    endif
  endif
  return s:ParseResult.success(res, input)
endfunction
function! s:seq.at(at, ...)
  let s:p = self.clone()
  let s:p.point = a:at
  if a:0
    let s:p.end = a:1
  endif
  return s:p
endfunction
function! s:seq.toString()
  return '(' . join(map(copy(self.parsers), 'v:val.toString()')) . ')'
endfunction

function! s:Parsers.seq(...)
  return s:seq.new(map(copy(a:000), 'self.asParser(v:val)'))
endfunction



let s:or = s:Parser.extend().named('or')
function! s:or.initialize(parsers)
  let self.parsers = a:parsers
endfunction
function! s:or.apply(input)
  for p in self.parsers
    let result = p.parse(a:input)
    if result.successful
      return result
    endif
  endfor
  return result
endfunction
function! s:or.toString()
  return '(' . join(map(copy(self.parsers), 'v:val.toString()'), ' | ') . ')'
endfunction

function! s:Parsers.or(...)
  return s:or.new(map(copy(a:000), 'self.asParser(v:val)'))
endfunction



let s:string = s:Parser.extend().named('string')
function! s:string.initialize(str)
  let self.string = a:str
  let self.len = strlen(a:str)
endfunction
function! s:string.apply(input)
  if !has_key(a:input, 'source') || type(a:input.source) != type('')
    return s:ParseResult.failure('not a StringReader', a:input)
  endif
  let source = a:input.source[a:input.offset :]
  return self.len <= strlen(source) && self.string ==# source[: self.len - 1]
  \   ? s:ParseResult.success(self.string,
  \       s:StringReader.new(a:input.source, a:input.offset + self.len))
  \   : s:ParseResult.failure(
  \     printf('"%s" expected but "%s" found', self.string, a:input.first()),
  \                           a:input)
endfunction
function! s:string.toString()
  return '"' . escape(self.string, '"\') . '"'
endfunction

function! s:Parsers.string(str)
  return s:string.new(a:str)
endfunction



let s:regex = s:Parser.extend().named('regex')
function! s:regex.initialize(pat)
  let self.pattern = a:pat
endfunction
function! s:regex.apply(input)
  if !has_key(a:input, 'source') || type(a:input.source) != type('')
    return s:ParseResult.failure('not a StringReader.', a:input)
  endif
  let source = a:input.source[a:input.offset :]
  let pat = '^' . self.pattern
  if source =~# pat
    let s = matchstr(source, pat)
    return s:ParseResult.success(s,
  \        s:StringReader.new(a:input.source, a:input.offset + strlen(s)))
  endif
  return s:ParseResult.failure(
  \ printf('string matching regex "%s" expected but "%s" found',
  \        self.pattern, a:input.first()), a:input)
endfunction
function! s:regex.toString()
  return '/' . escape(self.pattern, '/') . '/'
endfunction

function! s:Parsers.regex(pattern)
  return s:regex.new(a:pattern)
endfunction




let s:lazy = s:Parser.extend().named('lazy')
function! s:lazy.apply(input)
  return self.parser.parse(a:input)
endfunction
function! s:lazy.set(parser)
  let self.parser = a:parser
endfunction

function! s:Parsers.lazy()
  return s:lazy.new()
endfunction




let s:constant = s:Parser.extend().named('constant')
function! s:constant.initialize(obj)
  let self.obj = a:obj
endfunction
function! s:constant.apply(input)
  return s:ParseResult.success(self.obj, a:input)
endfunction
function! s:constant.toString()
  return 'constant(' . s:toString(self.obj) . ')'
endfunction

function! s:Parsers.constant(obj)
  return s:constant.new(a:obj)
endfunction

function! s:Parsers.always()
  return s:constant.new(s:null)
endfunction



function! s:Parsers.asParser(p)
  if type(a:p) == type('')
    return self.string(a:p)
  elseif type(a:p) == type([])
  endif
  return a:p
endfunction




" ----------------------------------------------------------------------------
" Parser
let s:map = s:Parser.extend().named('map')
function! s:map.initialize(parser, func)
  let self.parser = a:parser
  let self.func = a:func
endfunction
function! s:map.apply(input)
  let result = self.parser.parse(a:input)
  return result.successful
  \ ? s:ParseResult.success(self.func(result.result), result.next)
  \ : result
endfunction
function! s:map.toString()
  return self.parser.toString()
endfunction


function! s:Parser.map(func)
  return s:map.new(self, a:func)
endfunction




let s:return = s:Parser.extend().named('return')
function! s:return.initialize(parser, returns)
  let self.parser = a:parser
  let self.returns = a:returns
endfunction
function! s:return.apply(input)
  let result = self.parser.parse(a:input)
  return result.successful
  \ ? s:ParseResult.success(self.returns, result.next)
  \ : result
endfunction
function! s:return.toString()
  return self.parser.toString()
endfunction


function! s:Parser.return(o)
  return s:return.new(self, o)
endfunction




let s:many = s:Parser.extend().named('many')
function! s:many.initialize(parser)
  let self.parser = a:parser
endfunction
function! s:many.apply(input)
  let input = a:input
  let res = []
  while 1
    let result = self.parser.parse(input)
    if !result.successful
      break
    endif
    let input = result.next
    call add(res, result.result)
  endwhile
  return s:ParseResult.success(res, input)
endfunction
function! s:many.toString()
  return self.parser.toString() . '*'
endfunction

function! s:Parser.many()
  return s:many.new(self)
endfunction

let s:sep = {}
function! s:sep.flatten(r)  " FIXME: wrong name
  return [a:r[0]] + a:r[1]
endfunction

function! s:Parser.many1()
  return self.next(self.many()).map(s:sep.flatten).named('many1')
endfunction



function! s:Parser.or(p)
  return s:Parsers.or(self, a:p)
endfunction



function! s:Parser.opt()
  return self.or(s:Parsers.always())
endfunction


function! s:Parser.sepBy(delim)
  return self.sepBy1(a:delim).opt()
endfunction

function! s:Parser.sepBy1(delim)
  return self.next(a:delim.next(self).at(1).many()).map(s:sep.flatten)
endfunction

function! s:Parser.sepEndBy(delim)
  return self.sepBy1(a:delim).opt()
endfunction

function! s:Parser.sepEndBy1(delim)
  return self.sepBy1(a:delim).followedBy(a:delim.opt())
endfunction


function! s:Parser.next(p)
  return s:Parsers.seq(self, a:p)
endfunction

function! s:Parser.followedBy(p)
  return self.next(a:p).at(0)
endfunction


function! s:Parser.phrase()
  return self.followedBy(s:Parsers.eof())
endfunction


function! s:Parser.lexer(...)
  let delim = a:0 ? a:1 : s:Parsers.regex('\s*')
  return delim.opt().next(self.sepEndBy(delim)).at(1)
endfunction





function! vparsec#parsers()
  return s:Parsers.extend()
endfunction

function! vparsec#scanner(str, token)
  return s:Scanner.new(a:str, a:token)
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
