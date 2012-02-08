# c.f. https://github.com/dadooda/irb_hacks

@reminders += [
  %Q{
IrbHacks Snippets:
irb> ae
(snippet)>> args.first.each(&block)
irb> a([1,2,3]) {|v| puts v}
1
2
3
},
  %Q{
IrbHacks Snippets (ae to edit, a to execute) persist b/w irb sessions and snippet history is accessible with up arrow
},
  %Q{
IrbHacks Paging:
irb> less <var>
<opens less to page over var.inspect>
},
  %Q{
IrbHacks.break():
# add 'IrbHacks.break(interesting_variable)' somewhere in your code
irb> ae
(snippet)>> <a call that will trigger your IrbHacks.break line>
irb> p interesting_variable
}
]

IRB.gem('irb_hacks')
