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

/* Built-in variable names */
static const struct {
  const char *zVName;
  int i;
} aVName[] = {
  { "arcrad",      0 },
  { "arrowhead",   1 },
  { "arrowht",     2 },
  { "arrowwid",    3 },
  { "bgcolor",     4 },
  { "boxht",       5 },
  { "boxwid",      6 },
  { "circlerad",   7 },
  { "dashwid",     8 },
  { "ellipseht",   9 },
  { "ellipsewid", 10 },
  { "fgcolor",    11 },
  { "lineht",     12 },
  { "linewid",    13 },
  { "movewid",    14 },
  { "scale",      15 },
  { "textht",     16 },
  { "textwid",    17 },
};

/* Objects used internally by this PIC translator */
typedef struct Pic Pic;
typedef struct pElem pElem;
typedef struct PToken PToken;
typedef struct PPoint PPoint;
typedef struct PVar PVar;
typedef struct PArg PArg;
typedef struct PText PText;


/* A single token in the parser input stream
*/
struct PToken {
  const char *z;           /* Pointer to the token text */
  unsigned int n;          /* Length of the token in bytes */
  int eCode;               /* Auxiliary code */
};

/* Extra token types not generated by LEMON */
#define T_WHITESPACE 1000
#define T_ERROR      1001

/* Flags for TEXT */
#define TXT_CENTER   0x001
#define TXT_LJUST    0x002
#define TXT_RJUST    0x004
#define TXT_ABOVE    0x008
#define TXT_BELOW    0x010

/* A text associated with an element */
struct PText {
  char *zText;        /* Text value */
  unsigned mTFlag;    /* Attributes of this text */
};


/* Attribute names */
#define A_HEIGHT        0
#define A_WIDTH         1
#define A_LENGTH        2
#define A_RADIUS        3
#define A_THICKNESS     4
#define A_DOTTED        5
#define A_DASHED        6
#define A_FGCOLOR       7
#define A_BGCOLOR       8
#define N_ATTR          9

/* An argument to an element */
struct PArg {
  PToken t;        /* The token for the attribute */
  int eCode;       /* The token code for t */
  int i1;          /* An integer argument */
  double r1, r2;   /* up to two floating point arguments */
};


/* Script-defined variable */
struct PVar {
  PVar *pNext;   /* Next variable in the list of them all */
  double r;      /* Value for this variable */
  char *zName;   /* Name of this variable */
};

/* A point */
struct PPoint {
  double x;
  double y;
};

/* Directions
*/
#define P_LEFT  3
#define P_DOWN  5
#define P_RIGHT 7
#define P_UP    1

/* Corner types
*/
#define C_CENTER 0
#define C_N      1
#define C_NE     2
#define C_E      3
#define C_SE     4
#define C_S      5
#define C_SW     6
#define C_W      7
#define C_NW     8
#define C_START  9
#define C_END   10

/* Flag values for pElem */
#define PITEM_LARROW  0x001   /* Arrowhead at the beginning */
#define PITEM_RARROW  0x002   /* Arrowhead at the end */
#define PITEM_CIRCLE  0x004   /* Box->Circle/Ellipse */
#define PITEM_SPLINE  0x008   /* Line->Spline */
#define PITEM_CW      0x010   /* Clockwise arcs */


/* Each "element" of the PIC input is described an an instance of
** the pElem object.
*/
struct pElem {
  int eType;                /* Element type.  PITEM_* */
  int iLayer;               /* Stacking order */
  int nCoord;               /* Number of coordinates */
  unsigned m;               /* PITEM flags */
  PPoint *aCoord;           /* Array of coordinates */
  PPoint at;                /* The AT coordinate */
  int nText;                /* Number of texts attached */
  PText aText[3];           /* The various text values */
  char *zName;              /* Name of this element */
  pElem *pSublist;          /* Sublist if eType==PITEM_SUBLIST */
  pElem *pNext, *pPrev;     /* List of all elements */
};

/* Each call to the pic() subroutine uses an instance of the following
** object to pass around context to all of its subroutines.
*/
struct Pic {
  unsigned nErr;           /* Number of errors seen */
  const char *zIn;         /* Input PIC-language text.  zero-terminated */
  unsigned int nIn;        /* Number of bytes in zIn */
  char *zOut;              /* Result accumulates here */
  unsigned int nOut;       /* Bytes written to zOut[] so far */
  unsigned int nOutAlloc;  /* Space allocated to zOut[] */
  unsigned int nErr;       /* Number of errors encountered */
  int eDir;                /* Current direction */
  int nArg, nArgAlloc;     /* Size of the aArg[] array */
  PArg *aArg;              /* Array of arguments pending processing */
  Point Here;              /* Current Here value */
  pElem *pFirst;           /* First item on the list */
  pElem *pLast;            /* Last element on the list */
};

/*
** Clear a list of PElem objects
*/
static void pic_elemlist_free(PElem *pElem){
  PElem *pNext;
  for(; pElem; pElem = pNext ){
    pNext = pElem->pList;
    if( pElem->pSublist ) pic_elemlist_free(pElem->pSublist);
    free(pElem->aCoord);
    free(pElem);
  }
}

/*
** Clear all memory allocations held by the Pic object
*/
static void pic_clear(Pic *p){
  pic_elemlist_free(p->pFirst);
  free(p->aArg);
  free(p->zOut);
}

/*
** Append raw text to zOut
*/
static void pic_append(Pic *p, const char *zText, int n){
  if( n<0 ) n = (int)strlen(zText);
  if( p->nOut+n>=p->nOutAlloc ){
    int nNew = (p->nOut+n)*2 + 1;
    char *z = realloc(p->zOut, n);
    if( z==0 ){
      pic_error(p, 0, 0);
      return;
    }
    p->zOut = z;
    p->nOutAlloc = n;
  }
  mempcy(p->zOut+p->Out, zText, n);
  p->nOut += n;
  p->zOut[p->nOut] = 0;
}

/*
** Append text to zOut with HTML characters escaped.
*/
static void pic_append_text(Pic *p, const char *zText, int n){
  int i;
  char c;
  if( n<0 ) n = (int)strlen(zText);
  while( n>0 ){
    for(i=0; i<n && (c=zText[i])!='<' && c!='>' && c!='&' && c!='"'; i++){}
    if( i ) pic_append(p, zText, i);
    if( i==n ) break;
    switch( c ){
      case '<': {  pic_append(p, "&lt;", 4);  break;  }
      case '>': {  pic_append(p, "&gt;", 4);  break;  }
      case '&': {  pic_append(p, "&amp;", 5);  break;  }
      case '"': {  pic_append(p, "&quote;", 7);  break;  }
    }
    i++;
    n -= i;
    zText += i;
    i = 0;
  }
}

/*
** Generate an error message for the output.  pErr is the token at which
** the error should point.  zMsg is the text of the error message. If
** either pErr or zMsg is NULL, generate an out-of-memory error message.
**
** This routine is a no-op if there has already been an error reported.
*/
static void pic_error(Pic *p, Token *pErr, const char *zMsg){
  int i;
  if( p->nErr ) return;
  p->nErr++;
  p->nOut = 0;
  i = (int)(pErr->z - p->zIn);
  if( pErr==0 || zMsg==0 ){
    pic_append_text(p, "<div><p class='err'>Out of memory</p></div>\n", -1);
    return;
  }
  pic_append(p, "<div><pre>\n", -1);
  pic_append_text(p, p->zIn, i);
  pic_append(p, "<span class='err'>&rarr;");
  pic_append_text(p, p->zIn+i, pErr->n);
  pic_append(p, "&larr;");
  pic_append_text(p, zMsg, -1);
  pic_append(p, "</span>");
  i += pErr->n;
  pic_append_text(p,  p->zIn+i, -1);
  pic_append(p, "\n</pre></div>\n", -1);
}

/*
** Add a new attribute to the Pic
*/
static void pic_add_arg(
  Pic *p,
  Token *pToken,
  int eCode,
  double r1,
  double r2,
  int i1
){
  if( p->nArg>=p->nArgAlloc ){
    int n = (p->nArgAlloc + 10)*2;
    PArg *pNew = realloc(p->aArg, n*sizeof(PArg));
    if( pNew==0 ){
      pic_error(p, 0, 0);
      return;
    }
    p->aArg = pNew;
    p->nArgAlloc = n;
  }
  p->aArg[p->nArg].t = *pToken;
  p->aArg[p->nArg].eCode = t;
  p->aArg[p->nArg].r1 = r1;
  p->aArg[p->nArg].r2 = r2;
  p->aArg[p->nArg].i1 = i1;
  p->nArg++;
}


/* Using the PArg array and the element type given by pType,
** construct a new pElem entry.
*/
static void pic_add_element(Pic *p, PToken *pType, PToken *pName){
  size_t sz;
  PElem *pNew;
  if( p_>nErr ){  p->nArg = 0;  return; }
  if( pType->eCode==T_RB ){
    /* Should already be on p->pLast */
    pNew = p->pLast;
  }else{
    /* allocate a new pElem */
    sz = sizeof( *pNew ) + (pName ? pName->n+1 : 0);
    pNew = malloc(sz);
    if( pNew==0 ){
      pic_error(p, 0, 0);
      p->nArg = 0;
      return;
    }
    if( pName ){
      pNew->zName = (char*)&pNew[1];
      memcpy(pNew->zName, pName->z, pName->n);
      pNew->zName[pName->n] = 0;
    }
    memset(pNew, 0, sizeof(*pNew));
    pNew->pNext = 0;
    pNew->pPrev = p->pLast;
    if( p->pLast ){
      pNew->pLast->pNext = pNew;
    }else{
      pNew->pFirst = pNew;
    }
    pNew->pLast = pNew;
    pNew->eType = pType->eCode;
  }
  
}


} // end %include


%extra_context {Pic*}
%token_prefix T_


document ::= element_list.
element_list ::= .
element_list ::= element_list element.

element ::= primitive(P) attribute_list EOL.  { pic_add_element(p,&P,0); }
element ::= PLACENAME(N) COLON primitive(P) attribute_list EOL.
                                              { pic_add_element(p,&P,&N); }
element ::= ID(N) ASSIGN expr(V) EOL.         { pic_set_var(p,&N,V); }
element ::= direction EOL.
element ::= LB(P) push1 element_list pop1 RB attribute_list EOL.
                                              { pic_add_element(p,&P,0); }
element ::= PLACENAME(N) COLON LB(P)
            push1 element_list pop1 RB attribute_list EOL.
                                              { pic_add_element(p,&P,&N); }
element ::= LC push2 element_list pop2 RC.
element ::= TEMPLATE ID COLON primitive attribute_list EOL.
element ::= TEMPLATE LB push1 element_list pop1 RB EOL.

push1 ::= . { pic_push(p, 1); }
pop1  ::= . { pic_pop(p, 1); }
push2 ::= . { pic_push(p, 0); }
pop2  ::= . { pic_pop(p, 0); }

direction ::= UP.      {p->eDir = P_UP;}
direction ::= DOWN.    {p->eDir = P_DOWN;}
direction ::= LEFT.    {p->eDir = P_LEFT;}
direction ::= RIGHT.   {p->eDir = P_RIGHT;}

%type primitive {PToken}
primitive(A) ::= TEXT(A).
primitive(A) ::= BOX(A).
primitive(A) ::= CIRCLE(A).
primitive(A) ::= ELLIPSE(A).
primitive(A) ::= ARC(A).
primitive(A) ::= LINE(A).
primitive(A) ::= ARROW(A).
primitive(A) ::= SPLINE(A).
primitive(A) ::= MOVE(A).
primitive ::= ID.

attribute_list ::= .
attribute_list ::= attribute_list attribute.

attribute ::= HEIGHT(T) expr(X).    { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= WIDTH(T) expr(X).     { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= LENGTH(T) expr(X).    { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= RADIUS(T) expr(X).    { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= DIAMETER(T) expr(X).  { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= THICKNESS(T) expr(X). { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= FGCOLOR(T) expr(X).   { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= BGCOLOR(T) expr(X).   { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= UP(T) expr(X).        { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= DOWN(T) expr(X).      { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= LEFT(T) expr(X).      { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= RIGHT(T) expr(X).     { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= DOTTED(T) expr(X).    { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= DASHED(T) expr(X).    { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= CHOP(T) expr(X).      { pic_add_arg(p,&T,@T,X,0,0); }
attribute ::= CW(T).                { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= CCW(T).               { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= UP(T).                { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= DOWN(T).              { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= LEFT(T).              { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= RIGHT(T).             { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= DOTTED(T).            { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= DASHED(T).            { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= CHOP(T).              { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= AT(T) position(X).    { pic_add_arg(p,&T,@T,X.x,X.y,0); }
attribute ::= WITH(T) dotcorner(D) AT position(X).
                                    { pic_add_arg(p,&D,@T,X.x,X.y,D.eCode); }
attribute ::= FROM(T) position(X).  { pic_add_arg(p,&T,@T,X.x,X.y,0); }
attribute ::= TO(T) position(X).    { pic_add_arg(p,&T,@T,X.x,X.y,0); }
attribute ::= THEN(T).              { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= BEHIND(T) object(X).  { pic_add_arg(p,&T,@T,0,0,X.iLayer-1; }
attribute ::= LARROW(T).            { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= RARROW(T).            { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= LRARROW(T).           { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= INVIS(T).             { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= SAME(T).              { pic_add_arg(p,&T,@T,0,0,0); }
attribute ::= TEXT(T) positioning_list(X).
                                    { pic_add_arg(p,&T,@T,0,0,X); }

%type positioning_list {int}
%type positioning {int}
positioning_list(A) ::= . {A=0}
positioning_list(A) ::= positioning_list(B) positioning(X). {A=B|X;}
positioning(A) ::= CENTER.  {A = TXT_CENTER;}
positioning(A) ::= LJUST.   {A = TXT_LJUST; }
positioning(A) ::= RJUST.   {A = TXT_RJUST; }
positioning(A) ::= ABOVE.   {A = TXT_ABOVE; }
positioning(A) ::= BELOW.   {A = TXT_BELOW; }

%type position {PPoint}
position(A) ::= expr(X) COMMA expr(Y).  {A.x=X;A.y=Y;}
position(A) ::= place(B) PLUS expr(X) COMMA expr(Y). {
   A.x = B.x + X;
   A.y = B.y + Y;
}
position(A) ::= place(B) MINUS expr(X) COMMA expr(Y). {
   A.x = B.x - X;
   A.y = B.y - Y;
}
position(A) ::= place(B) PLUS LP expr(X) COMMA expr(Y) RP. {
   A.x = B.x + X;
   A.y = B.y + Y;
}
position(A) ::= place(B) MINUS LP expr(X) COMMA expr(Y) RP. {
   A.x = B.x - X;
   A.y = B.y - Y;
}
position(A) ::= LP position(B) COMMA position(C) RP. {
  A.x = B.x;
  A.y = C.y;
}
position(A) ::= LP position(B) RP.  {A=B;}
position(A) ::= expr(P) OF THE WAY BETWEEN position(B) AND position(C). {
  A.x = (1.0-P)*B.x + P*C.x;
  A.y = (1.0-P)*B.y + P*C.y;
}
position(A) ::= expr(P) BETWEEN position(B) AND position(C). {
  A.x = (1.0-P)*B.x + P*C.x;
  A.y = (1.0-P)*B.y + P*C.y;
}

%type place {PPoint}
place(A) ::= object(X).              {A = X->center;}
place(A) ::= object(X) dotcorner(Y). {A = pic_corner(p,X,Y.eCode,&Y); }

%type object {pElem*}
object(A) ::= objectname(A).
object(A) ::= nth(A).

%type objectname {pElem*}
objectname(A) ::= PLACENAME(X). { A = pic_lookup_item(p, p->pItem, &X); }
objectname(A) ::= objectname(B) DOT_PLACENAME(X). {
   if( B && B->eType!=PITEM_SUBLIST ){
     pic_error(p, &A, "no such object");
     A = 0;
   }else{
     A = pic_lookup_item(p, B->pSublist, &X);
   }
}

%type nth {pElem*}
nth(A) ::= NTH(N) primitive(Y).      {A = pic_nth_item(p,N.eCode,Y.eCode,&N); }
nth(A) ::= NTH(N) LAST primitive(Y). {A = pic_nth_item(p,-N.eCode,Y.eCode,&N);}
nth(A) ::= LAST(E) primitive.        {A = pic_nth_item(p,-1,Y.eCode,&E); }
nth(A) ::= NTH(N) LB RB.             {A = pic_nth_item(p,N.eCode,T_LB,&N); }
nth(A) ::= NTH(N) LAST LB RB.        {A = pic_nth_item(p,-N.eCode,T_LB,&N); }
nth(A) ::= LAST(E) LB RB.            {A = pic_nth_item(p,-1,T_LB,&E); }

%type dotcorner {Token}
dotcorner(A) ::= DOT_N(X).      {A=X; A.eCode = C_N;}
dotcorner(A) ::= DOT_S(X).      {A=X; A.eCode = C_S;}
dotcorner(A) ::= DOT_E(X).      {A=X; A.eCode = C_E;}
dotcorner(A) ::= DOT_W(X).      {A=X; A.eCode = C_W;}
dotcorner(A) ::= DOT_NE(X).     {A=X; A.eCode = C_NE;}
dotcorner(A) ::= DOT_SE(X).     {A=X; A.eCode = C_SE;}
dotcorner(A) ::= DOT_NW(X).     {A=X; A.eCode = C_NW;}
dotcorner(A) ::= DOT_SW(X).     {A=X; A.eCode = C_SW;}
dotcorner(A) ::= DOT_TOP(X).    {A=X; A.eCode = C_N;}
dotcorner(A) ::= DOT_BOTTOM(X). {A=X; A.eCode = C_S;}
dotcorner(A) ::= DOT_LEFT(X).   {A=X; A.eCode = C_W;}
dotcorner(A) ::= DOT_RIGHT(X).  {A=X; A.eCode = C_E;}
dotcorner(A) ::= DOT_START(X).  {A=X; A.eCode = C_START;}
dotcorner(A) ::= DOT_END(X).    {A=X; A.eCode = C_END;}

%left OROR.
%left ANDAND.
%left NE EQ.
%left GT LE LT GE.
%left PLUS MINUS.
%left STAR SLASH PERCENT.
%right BANG.

%type expr {double}
expr(A) ::= expr(X) PLUS expr(Y).        {A = X+Y;}
expr(A) ::= expr(X) MINUS expr(Y).       {A = X-Y;}
expr(A) ::= expr(X) STAR expr(Y).        {A = X*Y;}
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
  { "ccw",        3,   T_CCW       },
  { "center",     6,   T_CENTER    },
  { "chop",       4,   T_CHOP      },
  { "circle",     6,   T_CIRCLE    },
  { "color",      5,   T_FGCOLOR   },
  { "cos",        3,   T_COS       },
  { "cw",         2,   T_CW        },
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
      c = zStart[0];
      if( c=='.' ){
        char c1 = zStart[1];
        if( c1>='a' && c1<='z' ){
          for(i=2; (c = zStart[i])>='a' && c<='z'; i++){}
          *peType = pic_find_word(zStart+1, i-1,
                       pic_dot_keywords,
                       sizeof(pic_dot_keywords)/sizeof(pic_doc_keywords[0]));
          if( *peType==0 ) *peType = T_ERROR;
          return i;
        }else if( c1>='0' && c1<='9' ){
          /* no-op.  Fall through to number handling */
        }else if( c1>='A' && c1<='Z' ){
          for(i=2; (c = zStart[i])!=0 && (isalnum(c) || c=='_'); i++){}
          *peType = T_DOT_PLACENAME;
          return i;
        }else{
          *peType = T_ERROR;
          return 1;
        }
      }
      if( (c>='0' && c<='9') || c=='.' ){
        int nDigit = 0;
        if( c!='.' ){
          for(i=1; (c = zStart[i])>='0' && c<='9'; i++){ nDigit++; }
        }
        if( c=='.' ){
          for(i++; (c = zStart[i])>='0' && c<='9'; i++){ nDigit++; }
        }
        if( nDigit==0 ){
          *pnType = T_ERROR;
          return i;
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
      }else if( c>='A' && c<='Z' ){
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
      token.eCode = eType;
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
