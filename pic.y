document ::= element_list.
element_list ::= .
element_list ::= element_list element.

element ::= primitive attribute_list EOL.
element ::= PLACENAME COLON element.
element ::= ID EQ expr EOL.
element ::= direction EOL.
element ::= LB element_list RB.
element ::= LC element_list RC.

direction ::= UP.
direction ::= DOWN.
direction ::= LEFT.
direction ::= RIGHT.

primitive ::= TEXT.
primitive ::= BOX.
primitive ::= CIRCLE.
primitive ::= ELLIPSE.
primitive ::= ARC.
primitive ::= LINE.
primitive ::= ARROW.
primitive ::= SPLINE.
primitive ::= MOVE.

attribute_list ::= .
attribute_list ::= attribute_list attribute.

attribute ::= HEIGHT expr.
attribute ::= WIDTH expr.
attribute ::= LENGTH expr.
attribute ::= RADIUS expr.
attribute ::= DIAMETER expr.
attribute ::= THICKNESS expr.
attribute ::= UP optexpr.
attribute ::= DOWN optexpr.
attribute ::= LEFT optexpr.
attribute ::= RIGHT optexpr.
attribute ::= AT position.
attribute ::= WITH dotcorner AT position.
attribute ::= FROM position.
attribute ::= TO position.
attribute ::= BY expr COMMAND expr.
attribute ::= THEN.
attribute ::= DOTTED optexpr.
attribute ::= DASHED optexpr.
attribute ::= CHOP optexpr.
attribute ::= OUTLINE color.
attribute ::= SHADED color.
attribute ::= BEHIND PLACENAME.
attribute ::= IN FRONT OF PLACENAME.
attribute ::= LARROW.
attribute ::= RARROW.
attribute ::= LRARROW.
attribute ::= INVIS.
attribute ::= SAME.
attribute ::= TEXT positioning_list.

color ::= ID.
color ::= COLOR.

positioning_list ::= .
positioning_list ::= positioning_list positioning.
positioning ::= CENTER.
positioning ::= LJUST.
positioning ::= RJUST.
positioning ::= ABOVE.
positioning ::= BELOW.

position ::= expr COMMA expr.
position ::= place PLUS expr COMMA expr.
position ::= place MINUS expr COMMA expr.
position ::= place PLUS LP expr COMMA expr RP.
position ::= place MINUS LP expr COMMA expr RP.
position ::= LP position COMMA position RP.
position ::= LP position RP.
position ::= expr OF THE WAY BETWEEN position AND position.
position ::= expr BETWEEN position AND position.

place ::= PLACENAME.
place ::= PLACENAME dotcorner.
place ::= nth.
place ::= nth dotcorner.

nth ::= NTH primitive.
nth ::= NTH LAST primitive.
nth ::= LAST primitive.

dotcorner ::= DOT_N.
dotcorner ::= DOT_S.
dotcorner ::= DOT_E.
dotcorner ::= DOT_W.
dotcorner ::= DOT_NE.
dotcorner ::= DOT_SE.
dotcorner ::= DOT_NW.
dotcorner ::= DOT_SW.
dotcorner ::= DOT_TOP.
dotcorner ::= DOT_BOTTOM.
dotcorner ::= DOT_LEFT.
dotcorner ::= DOT_RIGHT.
dotcorner ::= DOT_START.
dotcorner ::= DOT_END.

optexpr ::= .
optexpr ::= expr.

%left OROR.
%left ANDAND.
%left NE EQ.
%left GT LE LT GE.
%left PLUS MINUS.
%left STAR SLASH PERCENT.
%right BANG.

expr ::= expr PLUS expr.
expr ::= expr MINUS expr.
expr ::= expr STAR expr.
expr ::= expr SLASH expr.
expr ::= expr PERCENT expr.
expr ::= expr LT expr.
expr ::= expr LE expr.
expr ::= expr GT expr.
expr ::= expr GE expr.
expr ::= expr EQ expr.
expr ::= expr NE expr.
expr ::= expr ANDAND expr.
expr ::= expr OROR expr.
expr ::= MINUS expr. [BANG]
expr ::= BANG expr.
expr ::= LP expr RP.
expr ::= ID.
expr ::= NUMBER.
expr ::= place DOT_X.
expr ::= place DOT_Y.
expr ::= place DOT_HEIGHT.
expr ::= place DOT_WIDTH.
expr ::= place DOT_RADIUS.
expr ::= SIN LP expr RP.
expr ::= COS LP expr RP.
expr ::= ATAN2 LP expr COMMA expr RP.
expr ::= LOG LP expr RP.
expr ::= EXP LP expr RP.
expr ::= SQRT LP expr RP.
expr ::= MAX LP expr COMMA expr RP.
expr ::= MIN LP expr COMMA expr RP.
expr ::= INT LP expr RP.
