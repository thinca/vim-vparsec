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

let s:ListReader = s:Reader.extend()
function! s:ListReader.initialize(list, ...)
  let self.list = a:list
  let self.offset = a:0 ? a:1 : 0
endfunction
function! s:ListReader.atEnd()
  return len(self.list) - 1 <= self.offset
endfunction
function! s:ListReader.first()
  return self.list[self.offset]
endfunction
function! s:ListReader.rest()
  return self.atEnd() ? self : s:ListReader.new(self.list, self.offset + 1)
endfunction
function! s:ListReader.toString()
  return printf('ListReader(%s, %s)', string(self.list), self.offset)
endfunction



let s:StringReader = s:Reader.extend()
function! s:StringReader.initialize(str, ...)
  let self.source = a:str
  let self.offset = a:0 ? a:1 : 0
endfunction
function! s:StringReader.atEnd()
  return strlen(self.source) - 1 <= self.offset
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



let s:ParseResult = s:Object.extend()

let s:Success = s:ParseResult.extend()
function! s:Success.initialize(result, next)
  let self.successful = 1
  let self.result = a:result
  let self.next = a:next
endfunction
function! s:Success.toString()
  return 'Success(' . s:toString(self.result) . ', ' . s:toString(self.next) . ')'
endfunction

let s:Failure = s:ParseResult.extend()
function! s:Failure.initialize(mes, next)
  let self.successful = 0
  let self.message = a:mes
  let self.next = a:next
endfunction
function! s:Failure.toString()
  return 'Failure(' . self.message . ', ' . s:toString(self.next) . ')'
endfunction




let s:Parser = s:Object.extend()
function! s:Parser.parse(input)
  let input = self.toReader(a:input)
  return self.apply(input)
endfunction
function! s:Parser.apply(input)
  return s:Failure.new('abstract parser', input)
endfunction
function! s:Parser.toReader(input)
  if type(a:input) == type('')
    return s:StringReader.new(a:input)
  elseif type(a:input) == type([])
    return s:ListReader.new(a:input)
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
  \ ? s:Success.new(s:null, a:input)
  \ : s:Failure.new('end of input expected', a:input)
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
  return s:Success.new(res, input)
endfunction
function! s:seq.at(at, ...)
  let p = self.clone()
  let p.point = a:at
  if a:0
    let p.end = a:1
  endif
  return p
endfunction
function! s:seq.toString()
  return '(' . join(map(copy(self.parsers), 'v:val.toString()')) . ')'
endfunction

function! s:Parsers.seq(...)
  return s:seq.new(map(copy(a:000), 'self.toParser(v:val)'))
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
  return s:or.new(map(copy(a:000), 'self.toParser(v:val)'))
endfunction



let s:string = s:Parser.extend().named('string')
function! s:string.initialize(str)
  let self.string = a:str
  let self.len = strlen(a:str)
endfunction
function! s:string.apply(input)
  if !has_key(a:input, 'source') || type(a:input.source) != type('')
    return s:Failure.new('not a StringReader', a:input)
  endif
  let source = a:input.source[a:input.offset :]
  return self.len <= strlen(source) && self.string ==# source[: self.len - 1]
  \   ? s:Success.new(self.string,
  \       s:StringReader.new(a:input.source, a:input.offset + self.len))
  \   : s:Failure.new(
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
    return s:Failure.new('not a StringReader.', a:input)
  endif
  let source = a:input.source[a:input.offset :]
  let pat = '^' . self.pattern
  if source =~# pat
    let s = matchstr(source, pat)
    return s:Success.new(s,
  \        s:StringReader.new(a:input.source, a:input.offset + strlen(s)))
  endif
  return s:Failure.new(
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
  return s:Success.new(self.obj, a:input)
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



function! s:Parsers.toParser(p)
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
  \ ? s:Success.new(self.func(result.result), result.next)
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
  \ ? s:Success.new(self.returns, result.next)
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
  return s:Success.new(res, input)
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


function! s:Parser.lexer(delim)
  return a:delim.opt().next(self.sepEndBy(a:delim)).at(1)
endfunction





function! vparsec#parsers()
  return s:Parsers.extend()
endfunction




let s:TokenParser = s:Parser.extend().named('token')
function! s:TokenParser.initialize(p)
  let self.parser = a:p
endfunction
function! s:TokenParser.apply(input)
  let f = a:input.first()
  let result = self.parser.phrase().parse(s:StringReader.new(f))
  return result.successful
  \ ? s:Success.new(result.result, a:input.rest())
  \ : s:Failure.new(
  \   printf('"%s" expected but "%s" found', self.parser.toString(), f), a:input)
endfunction
function! s:TokenParser.toString()
  return '`' . self.parser.toString() . '`'
endfunction


let s:Scanners = s:Parsers.extend()
function! s:Scanners.toParser(p)
  let p = self.super.toParser(a:p)
  if type(p) == type({}) && (has_key(p, 'string') || has_key(p, 'pattern'))
    return s:TokenParser.new(p)
  endif
  return p
endfunction

function! vparsec#scanners()
  return s:Scanners.new()
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
