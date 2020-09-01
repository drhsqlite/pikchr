%include {
/*
** 2020-09-01
**
** A translator for the PIC language into SVG.
**
** This code was originally written by D. Richard Hipp using documentation
** from prior PIC implementations but without reference to prior code.
** All of the code in this project is original.  The author releases all
** code into the public domain.
**
** This file implements a C-language subroutine that accepts a string
** of PIC language text and generates a second string of SVG output that
** renders the drawing defined by the input.  Space to hold the returned
** string is obtained from malloc() and should be freed by the caller.
** NULL might be returned if there is a memory allocation error.
**
** If there are error in the PIC input, the output will consist of an
** error message and the original PIC input text (inside of <pre>...</pre>).
**
** The subroutine implemented by this file is intended to be stand-alone.
** It uses no external routines other than routines commonly found in
** the standard C library.
*/
} // end %include

%name pic_parser
%token_type {PToken}
%extra_context {Pic *p}

%include {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

/* Chart of the 140 official HTML color names */
static const struct {
  const char *zColor;  /* Name of the color */
  unsigned int val;    /* RGB value */
} aColor[] = {
  { "AliceBlue",                   0xf0f8ff },
  { "AntiqueWhite",                0xfaebd7 },
  { "Aqua",                        0x00ffff },
  { "AquaMarine",                  0x7fffd4 },
  { "Azure",                       0xf0ffff },
  { "Beige",                       0xf5f5dc },
  { "Bisque",                      0xffe4c4 },
  { "Black",                       0x000000 },
  { "BlanchedAlmond",              0xffebcd },
  { "Blue",                        0x0000ff },
  { "BlueViolet",                  0x8a2be2 },
  { "Brown",                       0xa52a2a },
  { "BurlyWood",                   0xdeb887 },
  { "CadetBlue",                   0x5f9ea0 },
  { "Chartreuse",                  0x7fff00 },
  { "Chocolate",                   0xd2691e },
  { "Coral",                       0xff7f50 },
  { "CornFlowerBlue",              0x6495ed },
  { "Cornsilk",                    0xfff8dc },
  { "Crimson",                     0xdc143c },
  { "Cyan",                        0x00ffff },
  { "DarkBlue",                    0x00008b },
  { "DarkCyan",                    0x008b8b },
  { "DarkGoldenRod",               0xb8860b },
  { "DarkGray",                    0xa9a9a9 },
  { "DarkGreen",                   0x006400 },
  { "DarkKhaki",                   0xbdb76b },
  { "DarkMagenta",                 0x8b008b },
  { "DarkOliveGreen",              0x556b2f },
  { "DarkOrange",                  0xff8c00 },
  { "DarkOrchid",                  0x9932cc },
  { "DarkRed",                     0x8b0000 },
  { "DarkSalmon",                  0xe9967a },
  { "DarkSeaGreen",                0x8fbc8f },
  { "DarkSlateBlue",               0x483d8b },
  { "DarkSlateGray",               0x2f4f4f },
  { "DarkTurquoise",               0x00ced1 },
  { "DarkViolet",                  0x9400d3 },
  { "DeepPink",                    0xff1493 },
  { "DeepSkyBlue",                 0x00bfff },
  { "DimGray",                     0x696969 },
  { "DodgerBlue",                  0x1e90ff },
  { "FireBrick",                   0xb22222 },
  { "FloralWhite",                 0xfffaf0 },
  { "ForestGreen",                 0x228b22 },
  { "Fuchsia",                     0xff00ff },
  { "Gainsboro",                   0xdcdcdc },
  { "GhostWhite",                  0xf8f8ff },
  { "Gold",                        0xffd700 },
  { "GoldenRod",                   0xdaa520 },
  { "Gray",                        0x808080 },
  { "Green",                       0x008000 },
  { "GreenYellow",                 0xadff2f },
  { "HoneyDew",                    0xf0fff0 },
  { "HotPink",                     0xff69b4 },
  { "IndianRed",                   0xcd5c5c },
  { "Indigo",                      0x4b0082 },
  { "Ivory",                       0xfffff0 },
  { "Khaki",                       0xf0e68c },
  { "Lavender",                    0xe6e6fa },
  { "LavenderBlush",               0xfff0f5 },
  { "LawnGreen",                   0x7cfc00 },
  { "LemonChiffon",                0xfffacd },
  { "LightBlue",                   0xadd8e6 },
  { "LightCoral",                  0xf08080 },
  { "LightCyan",                   0xe0ffff },
  { "LightGoldenrodYellow",        0xfafad2 },
  { "LightGray",                   0xd3d3d3 },
  { "LightGreen",                  0x90ee90 },
  { "LightPink",                   0xffb6c1 },
  { "LightSalmon",                 0xffa07a },
  { "LightSeaGreen",               0x20b2aa },
  { "LightSkyBlue",                0x87cefa },
  { "LightSlateGray",              0x778899 },
  { "LightSteelBlue",              0xb0c4de },
  { "LightYellow",                 0xffffe0 },
  { "Lime",                        0x00ff00 },
  { "LimeGreen",                   0x32cd32 },
  { "Linen",                       0xfaf0e6 },
  { "Magenta",                     0xff00ff },
  { "Maroon",                      0x800000 },
  { "MediumAquaMarine",            0x66cdaa },
  { "MediumBlue",                  0x0000cd },
  { "MediumOrchid",                0xba55d3 },
  { "MediumPurple",                0x9370d8 },
  { "MediumSeaGreen",              0x3cb371 },
  { "MediumSlateBlue",             0x7b68ee },
  { "MediumSpringGreen",           0x00fa9a },
  { "MediumTurquoise",             0x48d1cc },
  { "MediumVioletRed",             0xc71585 },
  { "MidnightBlue",                0x191970 },
  { "MintCream",                   0xf5fffa },
  { "MistyRose",                   0xffe4e1 },
  { "Moccasin",                    0xffe4b5 },
  { "NavajoWhite",                 0xffdead },
  { "Navy",                        0x000080 },
  { "OldLace",                     0xfdf5e6 },
  { "Olive",                       0x808000 },
  { "OliveDrab",                   0x6b8e23 },
  { "Orange",                      0xffa500 },
  { "OrangeRed",                   0xff4500 },
  { "Orchid",                      0xda70d6 },
  { "PaleGoldenRod",               0xeee8aa },
  { "PaleGreen",                   0x98fb98 },
  { "PaleTurquoise",               0xafeeee },
  { "PaleVioletRed",               0xdb7093 },
  { "PapayaWhip",                  0xffefd5 },
  { "PeachPuff",                   0xffdab9 },
  { "Peru",                        0xcd853f },
  { "Pink",                        0xffc0cb },
  { "Plum",                        0xdda0dd },
  { "PowderBlue",                  0xb0e0e6 },
  { "Purple",                      0x800080 },
  { "Red",                         0xff0000 },
  { "RosyBrown",                   0xbc8f8f },
  { "RoyalBlue",                   0x4169e1 },
  { "SaddleBrown",                 0x8b4513 },
  { "Salmon",                      0xfa8072 },
  { "SandyBrown",                  0xf4a460 },
  { "SeaGreen",                    0x2e8b57 },
  { "SeaShell",                    0xfff5ee },
  { "Sienna",                      0xa0522d },
  { "Silver",                      0xc0c0c0 },
  { "SkyBlue",                     0x87ceeb },
  { "SlateBlue",                   0x6a5acd },
  { "SlateGray",                   0x708090 },
  { "Snow",                        0xfffafa },
  { "SpringGreen",                 0x00ff7f },
  { "SteelBlue",                   0x4682b4 },
  { "Tan",                         0xd2b48c },
  { "Teal",                        0x008080 },
  { "Thistle",                     0xd8bfd8 },
  { "Tomato",                      0xff6347 },
  { "Turquoise",                   0x40e0d0 },
  { "Violet",                      0xee82ee },
  { "Wheat",                       0xf5deb3 },
  { "White",                       0xffffff },
  { "WhiteSmoke",                  0xf5f5f5 },
  { "Yellow",                      0xffff00 },
  { "YellowGreen",                 0x9acd32 },
};

/* Objects used internally by this PIC translator */
typedef struct Pic Pic;
typedef struct PItem PItem;
typedef struct PToken PToken;
typedef struct PPoint PPoint;

/* A point */
struct PPoint {
  double x;
  double y;
};

/* Item types
*/
#define PITEM_TEXT       1
#define PITEM_BOX        2
#define PITEM_CIRCLE     3
#define PITEM_ELLIPSE    4
#define PITEM_ARC        5
#define PITEM_LINE       6
#define PITEM_ARROW      7
#define PITEM_SPLINE     8
#define PITEM_MOVE       9
#define PITEM_SUBLIST   10

/* Directions
*/
#define P_LEFT  0
#define P_DOWN  1
#define P_RIGHT 2
#define P_UP    3

/* Each "element" of the PIC input is described an an instance of
** the PItem object.
*/
struct PItem {
  int eType;
  PItem *pNext, *pPrev;
};

/* Each call to the pic() subroutine uses an instance of the following
** object to pass around context to all of its subroutines.
*/
struct Pic {
  const char *zIn;         /* Input PIC-language text.  zero-terminated */
  unsigned int nIn;        /* Number of bytes in zIn */
  char *zOut;              /* Result accumulates here */
  unsigned int nOut;       /* Bytes written to zOut[] so far */
  unsigned int nOutAlloc;  /* Space allocated to zOut[] */
  unsigned int nErr;       /* Number of errors encountered */
  PItem *pList;            /* List of elements */
};

/* A single token in the parser input stream
*/
struct PToken {
  const char *z;           /* Pointer to the token text */
  unsigned int n;          /* Length of the token in bytes */
};

/* Extra token types not generated by LEMON */
#define T_WHITESPACE 1000
#define T_ERROR      1001


} // end %include


%extra_context {Pic*}
%token_prefix T_


document ::= element_list.
element_list ::= .
element_list ::= element_list element.

element ::= primitive attribute_list EOL.
element ::= PLACENAME COLON element.
element ::= ID ASSIGN expr EOL.
element ::= direction EOL.
element ::= LB element_list RB.
element ::= LC element_list RC.

direction ::= UP.      {p->eDir = P_UP;}
direction ::= DOWN.    {p->eDir = P_DOWN;}
direction ::= LEFT.    {p->eDir = P_LEFT;}
direction ::= RIGHT.   {p->eDir = P_RIGHT;}

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

attribute ::= HEIGHT expr(X).   { printf("x=%g\n", X) }
attribute ::= WIDTH expr.
attribute ::= LENGTH expr.
attribute ::= RADIUS expr.
attribute ::= DIAMETER expr.
attribute ::= THICKNESS expr.
attribute ::= UP expr.
attribute ::= DOWN expr.
attribute ::= LEFT expr.
attribute ::= RIGHT expr.
attribute ::= DOTTED expr.
attribute ::= DASHED expr.
attribute ::= CHOP expr.
attribute ::= UP.
attribute ::= DOWN.
attribute ::= LEFT.
attribute ::= RIGHT.
attribute ::= DOTTED.
attribute ::= DASHED.
attribute ::= CHOP.
attribute ::= AT position.
attribute ::= WITH dotcorner AT position.
attribute ::= FROM position.
attribute ::= TO position.
attribute ::= BY expr COMMA expr.
attribute ::= THEN.
attribute ::= FGCOLOR expr.
attribute ::= BGCOLOR expr.
attribute ::= BEHIND PLACENAME.
attribute ::= IN FRONT OF PLACENAME.
attribute ::= LARROW.
attribute ::= RARROW.
attribute ::= LRARROW.
attribute ::= INVIS.
attribute ::= SAME.
attribute ::= TEXT positioning_list.

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

%left OROR.
%left ANDAND.
%left NE EQ.
%left GT LE LT GE.
%left PLUS MINUS.
%left STAR SLASH PERCENT.
%right BANG.

%type expr {double}
expr(A) ::= expr(X) PLUS expr(Y).  {A = X+Y;}
expr(A) ::= expr(X) MINUS expr(Y). {A = X-Y;}
expr(A) ::= expr(X) STAR expr(Y).  {A = X*Y;}
expr(A) ::= expr(X) SLASH(E) expr(Y).    {A = pic_div(p, &X,&Y,&E);}
expr(A) ::= expr(X) PERCENT(E) expr(Y).  {A = pic_rem(p, &X,&Y,&E);}
expr(A) ::= expr(X) LT expr(Y).    {A = X<Y;}
expr(A) ::= expr(X) LE expr(Y).    {A = X<=Y;}
expr(A) ::= expr(X) GT expr(Y).    {A = X>Y;}
expr(A) ::= expr(X) GE expr(Y).    {A = X>=Y;}
expr(A) ::= expr(X) EQ expr(Y).    {A = X==Y;}
expr(A) ::= expr(X) NE expr(Y).    {A = X!=Y;}
expr(A) ::= expr(X) ANDAND expr(Y).{A = X && Y;}
expr(A) ::= expr(X) OROR expr(Y).  {A = X || Y;}
expr(A) ::= MINUS expr(X). [BANG]  {A = -X;}
expr(A) ::= PLUS expr(X). [BANG]  {A = X;}
expr(A) ::= BANG expr(X).   {A = !X;}
expr(A) ::= LP expr(X) RP.  {A = X;}
expr(A) ::= ID.             {A = pic_id_num(p, 0.0;}
expr(A) ::= NUMBER(X).      {A = pic_atof(p, &X);}
expr(A) ::= HEXRGB(X).      {A = pic_rgb_num(p, &X);}
expr(A) ::= place DOT_X.{A = 0.0;}
expr(A) ::= place DOT_Y.{A = 0.0;}
expr(A) ::= place DOT_HEIGHT.{A = 0.0;}
expr(A) ::= place DOT_WIDTH.{A = 0.0;}
expr(A) ::= place DOT_RADIUS.{A = 0.0;}
expr(A) ::= SIN LP expr RP.{A = 0.0;}
expr(A) ::= COS LP expr RP.{A = 0.0;}
expr(A) ::= ATAN2 LP expr COMMA expr RP.{A = 0.0;}
expr(A) ::= LOG LP expr RP.{A = 0.0;}
expr(A) ::= EXP LP expr RP.{A = 0.0;}
expr(A) ::= SQRT LP expr RP.{A = 0.0;}
expr(A) ::= MAX LP expr(X) COMMA expr(Y) RP.  {A = X>Y ? X : Y;}
expr(A) ::= MIN LP expr(X) COMMA expr(Y) RP.  {A = X<Y ? X : Y;}
expr(A) ::= INT LP expr(X) RP.  {A = (double)pic_int(X);}



/**************************************************************************
** Main processing code
*/
%code {
/* Compute the integer part of a floating point number */
int pic_int(double r){
  int i = (int)r;
  return i;
}


/*
** An array of this structure defines a list of keywords.
*/
struct PicWordlist {
  char *zWord;    /* Text of the keyword */
  int nChar;      /* Length of keyword text in bytes */
  int eType;      /* Token code */
};

/*
** Keywords
*/
static struct PicWordlist pic_keywords[] = {
  { "above",      5,   T_ABOVE     },
  { "and",        3,   T_AND       },
  { "arc",        3,   T_ARC       },
  { "arrow",      5,   T_ARROW     },
  { "at",         2,   T_AT        },
  { "atan2",      5,   T_ATAN2     },
  { "behind",     6,   T_BEHIND    },
  { "below",      5,   T_BELOW     },
  { "between",    7,   T_BETWEEN   },
  { "bgcolor",    7,   T_BGCOLOR   },
  { "box",        3,   T_BOX       },
  { "by",         2,   T_BY        },
  { "center",     6,   T_CENTER    },
  { "chop",       4,   T_CHOP      },
  { "circle",     6,   T_CIRCLE    },
  { "color",      5,   T_FGCOLOR   },
  { "cos",        3,   T_COS       },
  { "dashed",     6,   T_DASHED    },
  { "diam",       4,   T_DIAMETER  },
  { "diameter",   8,   T_DIAMETER  },
  { "dotted",     6,   T_DOTTED    },
  { "down",       4,   T_DOWN      },
  { "ellipse",    7,   T_ELLIPSE   },
  { "exp",        3,   T_EXP       },
  { "fgcolor",    7,   T_FGCOLOR   },
  { "from",       4,   T_FROM      },
  { "front",      5,   T_FRONT     },
  { "height",     6,   T_HEIGHT    },
  { "ht",         6,   T_HEIGHT    },
  { "in",         2,   T_IN        },
  { "int",        3,   T_INT       },
  { "invis",      5,   T_INVIS     },
  { "invisible",  9,   T_INVIS     },
  { "last",       4,   T_LAST      },
  { "left",       4,   T_LEFT      },
  { "len",        3,   T_LENGTH    },
  { "length",     6,   T_LENGTH    },
  { "line",       4,   T_LINE      },
  { "ljust",      5,   T_LJUST     },
  { "log",        3,   T_LOG       },
  { "max",        3,   T_MAX       },
  { "min",        3,   T_MIN       },
  { "move",       4,   T_MOVE      },
  { "of",         2,   T_OF        },
  { "outline",    7,   T_FGCOLOR   },
  { "rad",        3,   T_RADIUS    },
  { "radius",     6,   T_RADIUS    },
  { "right",      5,   T_RIGHT     },
  { "rjust",      5,   T_RJUST     },
  { "same",       4,   T_SAME      },
  { "shaded",     6,   T_BGCOLOR   },
  { "sin",        3,   T_SIN       },
  { "splite",     6,   T_SPLINE    },
  { "sqrt",       4,   T_SQRT      },
  { "the",        3,   T_THE       },
  { "then",       4,   T_THEN      },
  { "thick",      5,   T_THICKNESS },
  { "thickness",  9,   T_THICKNESS },
  { "to",         2,   T_TO        },
  { "up",         2,   T_UP        },
  { "way",        3,   T_WAY       },
  { "wid",        5,   T_WIDTH     },
  { "width",      5,   T_WIDTH     },
  { "with",       4,   T_WITH      },
};


/*
** Suffixes for "dot-tokens"
*/
static struct PicWordlist pic_dot_keywords[] = {
  { "bottom",     6,  T_DOT_BOTTOM },
  { "e",          1,  T_DOT_E      },
  { "end",        3,  T_DOT_END    },
  { "height",     6,  T_DOT_HEIGHT },
  { "ht",         2,  T_DOT_HEIGHT },
  { "left",       4,  T_DOT_LEFT   },
  { "n",          1,  T_DOT_N      },
  { "ne",         2,  T_DOT_NE     },
  { "nw",         2,  T_DOT_NW     },
  { "rad",        3,  T_DOT_RADIUS },
  { "radius",     6,  T_DOT_RADIUS },
  { "right",      5,  T_DOT_RIGHT  },
  { "s",          1,  T_DOT_S      },
  { "se",         2,  T_DOT_SE     },
  { "start",      5,  T_DOT_START  },
  { "sw",         2,  T_DOT_SW     },
  { "top",        3,  T_DOT_TOP    },
  { "w",          1,  T_DOT_W      },
  { "wid",        3,  T_DOT_WIDTH  },
  { "width",      5,  T_DOT_WIDTH  },
  { "x",          1,  T_DOT_X      },
  { "y",          1,  T_DOT_Y      },
}

/*
** Search a PicWordlist for the given keyword.  Return its code.
** Or return 0 if not found.
*/
static int pic_find_word(
  const char *zIn,              /* Word to search for */
  int n,                        /* Length of zIn */
  struct PicWordlist *aList,    /* List to search */
  int nList                     /* Number of entries in aList */
){
  int first = 0;
  int last = nList-1;
  int mid;
  while( first<=last ){
    int mid = (first + last)/2;
    int sz = aList[mid].nChar;
    int c = strncmp(zIn, aList[mid].zWord, sz<n ? sz : n);
    if( c==0 ){
      c = n - sz;
      if( c==0 ) return mid;
    }
    if( c<0 ){
      first = mid+1;
    }else{
      last = mid-1;
    }
  }
  return 0;
}



/*
** Return the length of next token  Write token type into *peType
*/
static int pic_token_length(const char *zStart, int *peType){
  int i;
  char c;
  switch( zStart[0] ){
    case '\\': {
      *peType = T_WHITESPACE;
      if( zStart[1]=='\n'  ) return 2;
      if( zStart[1]=='\r' && zStart[2]=='\n' ) return 3;
      *peType = T_ERROR;
      return 1;
    }
    case ';':
    case '\n': {
      *peType = T_EOL;
      return 1;
    }
    case '"': {
      for(i=1; (c = zStart[i])!=0; i++){
        if( c=='\\' ){ i++; continue; }
        if( c=='"' ){
          *peType = T_TEXT;
          return i+1;
        }
      }
      *peType = T_ERROR;
      return i;
    }
    case ' ':
    case '\t':
    case '\f':
    case '\r': {
      for(i=1; (c = zStart[i])==' ' || c=='\t' || c=='\r' || c=='\t'; i++){}
      *peType = T_WHITESPACE;
      return i;
    }
    case '#': {
      for(i=1; isxdigit(zStart[i]); i++){}
      if( i==4 || i==7 ){
        *peType = T_HEXRGB;
        return i;
      }
      for(i=1; (c = zStart[i])!=0 && c!='\n'; i++){}
      *peType = T_WHITESPACE;
      return i;
    }
    case '.': {
      for(i=1; (c = zStart[i])>='a' && c<='z'; i++){}
      *peType = pic_find_word(zStart+1, i-1,
                   pic_dot_keywords,
                   sizeof(pic_dot_keywords)/sizeof(pic_doc_keywords[0]));
      if( *peType==0 ) *peType = T_ERROR;
      return i;
    }
    case '+': {   *peType = T_PLUS;    return 1; }
    case '*': {   *peType = T_STAR;    return 1; }
    case '/': {   *peType = T_SLASH;   return 1; }
    case '%': {   *peType = T_PERCENT; return 1; }
    case '(': {   *peType = T_LP;      return 1; }
    case ')': {   *peType = T_RP;      return 1; }
    case '[': {   *peType = T_LB;      return 1; }
    case ']': {   *peType = T_RB;      return 1; }
    case '{': {   *peType = T_LC;      return 1; }
    case '}': {   *peType = T_RC;      return 1; }
    case ',': {   *peType = T_COMMA;   return 1; }
    case ':': {   *peType = T_COLON;   return 1; }
    case '-': {
      if( zStart[1]=='>' ){
        *peType = T_RARROW;
        return 2;
      }else{
        *peType = T_MINUS;
        return 1;
      }
    }
    case '=': { 
      if( zStart[1]=='=' ){
        *peType = T_EQ;  return 2;
      }else{
        *peType = T_ASSIGN; return 1;
      }
    }
    case '<': { 
      if( zStart[1]=='=' ){
        *peType = T_LE;  return 2;
      }else if( zStart[1]=='-' ){
         if( zStart[2]=='>' ){
           *peType = T_LRARROW;
           return 3;
         }else{
           *peType = T_LARROW;
           return 2;
         }
      }else{
        *peType = T_LT; return 1;
      }
    }
    case '>': { 
      if( zStart[1]=='=' ){
        *peType = T_GE;  return 2;
      }else{
        *peType = T_GT; return 1;
      }
    }
    case '!': { 
      if( zStart[1]=='=' ){
        *peType = T_NE;  return 2;
      }else{
        *peType = T_BANG; return 1;
      }
    }
    case '|': { 
      if( zStart[1]=='|' ){
        *peType = T_OROR;  return 2;
      }else{
        *peType = T_ERROR; return 1;
      }
    }
    case '&': { 
      if( zStart[1]=='&' ){
        *peType = T_ANDAND;  return 2;
      }else{
        *peType = T_ERROR; return 1;
      }
    }
    default: {
      c  = zStart[0];
      if( c>='0' && c<='9' ){
        for(i=1; (c = zStart[i])>='0' && c<='9'; i++){}
        if( c=='.' ){
          for(i++; (c = zStart[i])>='0' && c<='9'; i++){}
        }
        if( c=='e' || c=='E' ){
          i++;
          c = zStart[i];
          if( c=='+' || c=='-' ){
            i++;
            c = zStart[i];
          }
          if( c<'0' || c>'9' ){
            *peType = T_ERROR;
            return i;
          }
          i++;
          while( (c = zStart[i])>=0 && c<='9' ){ i++; }
        }else if( (c=='t' && zStart[i+1]=='h')
               || (c=='r' && zStart[i+1]=='d')
               || (c=='n' && zStart[i+1]=='d')
               || (c=='s' && zStart[i+1]=='t') ){
          *peType = T_NTH;
          return i+2;
        }
        *peType = T_NUMBER;
        return i;
      }else if( c>='a' && z<='z' ){
        for(i=1; (c =  zStart[i])!=0 && (isalnum(c) || c=='_'); i++){}
        *peType = pic_find_word(zStart+1, i-1,
                   pic_keywords,
                   sizeof(pic_keywords)/sizeof(pic_keywords[0]));

        if( *peType==0 ) *peType = T_ID;
        return i;
      }else if( c>='A' && z<='Z' ){
        for(i=1; (c =  zStart[i])!=0 && (isalnum(c) || c=='_'); i++){}
        *peType = T_PLACENAME;
        return i;
      }else{
        *peType = T_ERROR;
        return 1;
      }
    }
  }
}

/*
** Parse the PIC script contained in zText[]
*/
char *pic(const char *zText, int *pnErr){
  int i;
  int sz;
  int eType;
  PToken token;
  Pic s;
  yyParser sParse;
  memset(&s, 0, sizeof(s));
  s.zIn = zText;
  s.nIn = (unsigned int)strlen(zText);
  pic_parserInit(&sParse, &s);
  for(i=0; zText[i] && s.nErr==0; i+=sz){
    sz = pic_token_length(zText+i, &eType);
    if( eType==T_ERROR ){
      printf("Unknown token at position %d: \"%.*s\"\n", i, sz, zText+i);
      break;
    }else if( eType!=T_WHITESPACE ){
      token.z = zText + i;
      token.n = sz;
      pic_parser(&sParse, eType, token);
    }
  }
  if( s.nErr==0 ) pic_parser(&sParse, 0, 0);
  pic_parserFinalize(&sParser);
  if( pnErr ) *pnErr = s.nErr;
  if( s.zOut ){
    s.zOut[s.nOut] = 0;
    s.zOut = realloc(s.zOut, s.nOut+1);
  }
  return s.zOut;
}

int main(int argc, char **argv){
  int i;
  for(i=1; i<argc; i++){
    FILE *in;
    size_t sz;
    char *zIn;
    char *zOut;

    in = fopen(argv[i], "rb");
    if( in==0 ){
      fprintf(stderr, "cannot open \"%s\" for reading\n", argv[i]);
      continue;
    }
    fseek(in, 0, SEEK_END);
    sz = ftell(in);
    rewind(in);
    zIn = malloc( sz+1 );
    if( zIn==0 ){
      fprintf(stderr, "cannot allocate space for file \"%s\"\n", argv[i]);
      fclose(in);
      continue;
    }
    sz = fread(zIn, 1, sz, in);
    fclose(in);
    zIn[sz] = 0;
    zOut = pic(zIn, 0);
    free(zIn);
    if( zOut ){
      printf("%s", zOut);
      free(zOut);
    }
  }
  return 0; 
}

} // end %include
