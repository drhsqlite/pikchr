document ::= element_list.

element_list ::= element.
element_list ::= element_list EOL element.
element ::= direction.
element ::= ID ASSIGN expr.
element ::= PLACENAME COLON unnamed_element.
element ::= unnamed_element.
unnamed_element ::= ID attribute_list.
unnamed_element ::= STRING attribute_list.
unnamed_element ::= LB element_list RB attribute_list.
unnamed_element ::= LB RB attribute_list.

direction ::= UP.
direction ::= DOWN.
direction ::= LEFT.
direction ::= RIGHT.

attribute_list ::=.
attribute_list ::= attribute_list attribute.
attribute ::= numproperty expr PERCENT.
attribute ::= numproperty expr.
attribute ::= dashproperty expr.
attribute ::= dashproperty.
attribute ::= colorproperty expr.
attribute ::= direction expr.
attribute ::= direction.
attribute ::= FROM position.
attribute ::= TO position.
attribute ::= THEN.
attribute ::= boolproperty.
attribute ::= AT position.
attribute ::= WITH DOT_C COMPASSPOINT AT position.
attribute ::= WITH COMPASSPOINT AT position.
attribute ::= SAME.
attribute ::= SAME AS object.
attribute ::= BEHIND object.
attribute ::= STRING textposition.

numproperty ::= HEIGHT.
numproperty ::= WIDTH.
numproperty ::= RADIUS.
numproperty ::= RX.
numproperty ::= RY.
numproperty ::= DIAMETER.
numproperty ::= THICKNESS.

dashproperty ::= DOTTED.
dashproperty ::= DASHED.

colorproperty ::= FILL.
colorproperty ::= COLOR.

boolproperty ::= LARROW.
boolproperty ::= RARROW.
boolproperty ::= LRARROW.
boolproperty ::= INVIS.

textposition ::= .
textposition ::= textposition CENTER|LJUST|RJUST|ABOVE|BELOW.


position ::= expr COMMA expr.
position ::= place.
position ::= place PLUS expr COMMA expr.
position ::= place MINUS expr COMMA expr.
position ::= place PLUS LP expr COMMA expr RP.
position ::= place MINUS LP expr COMMA expr RP.
position ::= LP position COMMA position RP.
position ::= LP position RP.
position ::= expr OF THE WAY BETWEEN position AND position.
position ::= expr BETWEEN position AND position.
position ::= direction expr FROM position.

place ::= object.
place ::= object DOT_C COMPASSPOINT.
place ::= object DOT_L START.
place ::= object DOT_L END.
place ::= START OF object.
place ::= END OF object.
place ::= COMPASSPOINT OF object.

object ::= objectname.
object ::= nth.
object ::= nth OF|IN object.

objectname ::= PLACENAME.
objectname ::= objectname DOT_U PLACENAME.

nth ::= NTH PRIMNAME.
nth ::= NTH LAST PRIMNAME.
nth ::= LAST PRIMNAME.
nth ::= NTH LB RB.
nth ::= NTH LAST LB RB.
nth ::= LAST LB RB.

%left OF.
%left PLUS MINUS.
%left STAR SLASH PERCENT.
%right UMINUS.

expr ::= expr PLUS expr.
expr ::= expr MINUS expr.
expr ::= expr STAR expr.
expr ::= expr SLASH expr.
expr ::= MINUS expr. [UMINUS]
expr ::= PLUS expr. [UMINUS]
expr ::= LP expr RP.
expr ::= ID.
expr ::= NUMBER.
expr ::= HEXRGB.
expr ::= object DOT_L locproperty.
expr ::= object DOT_L numproperty.
expr ::= object DOT_L dashproperty.
expr ::= object DOT_L colorproperty.
expr ::= object DOT_C COMPASSPOINT DOT_L X.
expr ::= object DOT_C COMPASSPOINT DOT_L Y.
expr ::= FUNCNAME LP expr RP.
expr ::= FUNCNAME LP expr COMMA expr RP.

locproperty ::= X.
locproperty ::= Y.
locproperty ::= TOP.
locproperty ::= BOTTOM.
locproperty ::= LEFT.
locproperty ::= RIGHT.
