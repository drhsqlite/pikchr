%include {
/*
** Zero-Clause BSD license:
**
** Copyright (C) 2020-09-01 by D. Richard Hipp <drh@sqlite.org>
**
** Permission to use, copy, modify, and/or distribute this software for
** any purpose with or without fee is hereby granted.
**
****************************************************************************
**
** This software translates a PIC-inspired diagram language into SVG.
**
** PIKCHR (pronounced like "picture") is *mostly* backwards compatible
** with legacy PIC, though some features of legacy PIC are removed 
** (for example, the "sh" command is removed for security) and
** many enhancements are added.
**
** PIKCHR is designed for use in an internet facing web environment.
** In particular, PIKCHR is designed to safely generate benign SVG from
** source text that provided by a hostile agent. 
**
** This code was originally written by D. Richard Hipp using documentation
** from prior PIC implementations but without reference to prior code.
** All of the code in this project is original.
**
** This file implements a C-language subroutine that accepts a string
** of PIKCHR language text and generates a second string of SVG output that
** renders the drawing defined by the input.  Space to hold the returned
** string is obtained from malloc() and should be freed by the caller.
** NULL might be returned if there is a memory allocation error.
**
** If there are error in the PIKCHR input, the output will consist of an
** error message and the original PIKCHR input text (inside of <pre>...</pre>).
**
** The subroutine implemented by this file is intended to be stand-alone.
** It uses no external routines other than routines commonly found in
** the standard C library.
**
****************************************************************************
** COMPILING:
**
** The original source text is a mixture of C99 and "Lemon"
** (See https://sqlite.org/src/file/doc/lemon.html).  Lemon is an LALR(1)
** parser generator program, similar to Yacc.  The grammar of the
** input language is specified in Lemon.  C-code is attached.  Lemon
** runs to generate a single output file ("pikchr.c") which is then
** compiled to generate the Pikchr library.  This header comment is
** preserved in the Lemon output, so you might be reading this in either
** the generated "pikchr.c" file that is output by Lemon, or in the
** "pikchr.y" source file that is input into Lemon.  If you make changes,
** you should change the input source file "pikchr.y", not the
** Lemon-generated output file.
**
** Basic compilation steps:
**
**      lemon pikchr.y
**      cc pikchr.c -o pikchr.o
**
** Add -DPIKCHR_SHELL to add a main() routine that reads input files
** and sends them through Pikchr, for testing.  Add -DPIKCHR_FUZZ for
** -fsanitizer=fuzzer testing.
** 
****************************************************************************
** IMPLEMENTATION NOTES (for people who want to understand the internal
** operation of this software, perhaps to extend the code or to fix bugs):
**
** Each call to pikchr() uses a single instance of the Pik structure to
** track its internal state.  The Pik structure lives for the duration
** of the pikchr() call.
**
** The input is a sequence of objects or "elements".  Each element is
** parsed into a PElem object.  These are stored on an extensible array
** called PEList.  All parameters to each PElem are computed as the
** object is parsed.  (Hence, the parameters to a PElem may only refer
** to prior elements.) Once the PElem is completely assemblied, it is
** added to the end of a PEList and never changes thereafter - except,
** PElem objects that are part of a "[...]" block might have their
** absolute position shifted when the outer [...] block is positioned.
** But apart from this repositioning, PElem objects are unchanged once
** they are added to the list. The order of elements on a PEList does
** not change.
**
** After all input has been parsed, the top-level PEList is walked to
** generate output.  Sub-lists resulting from [...] blocks are scanned
** as they are encountered.  All input must be collected and parsed ahead
** of output generation because the size and position of elements must be
** known in order to compute a bounding box on the output.
**
** Each PElem is on a "layer".  (The common case is that all PElem's are
** on a single layer, but multiple layers are possible.)  A separate pass
** is made through the list for each layer.
**
** After all output is generated, the Pik object, and the all the PEList
** and PElem objects are deallocated and the generate output string is
** returned.  Upon any error, the Pik.nErr flag is set, processing quickly
** stops, and the stack unwinds.  No attempt is made to continue reading
** input after an error.
**
** Most elements begin with a class name like "box" or "arrow" or "move".
** There is a class named "text" which is used for elements that begin
** with a string literal.  You can also specify the "text" class.
** A Sublist ("[...]") is a single object that contains a pointer to
** its subelements, all gathered onto a separate PEList object.
**
** Variables go into PVar objects that form a linked list.
**
** Each PElem has zero or one names.  Input constructs that attempt
** to assign a new name from an older name, like:
**
**      Abc:  Abc + (0.5cm, 0)
**
** These generate a new "noop" object at the specified place and with
** the specified name.  As place-names are searched by scanning the list
** in reverse order, this has the effect of overriding the "Abc" name
** when referenced by subsequent objects.
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <assert.h>
#define count(X) (sizeof(X)/sizeof(X[0]))
#ifndef M_PI
# define M_PI 3.1415926535897932385
#endif

typedef struct Pik Pik;          /* Complete parsing context */
typedef struct PToken PToken;    /* A single token */
typedef struct PElem PElem;      /* A single diagram object or "element" */
typedef struct PEList PEList;    /* A list of elements */
typedef struct PClass PClass;    /* Description of elements types */
typedef double PNum;             /* Numeric value */
typedef struct PPoint PPoint;    /* A position in 2-D space */
typedef struct PVar PVar;        /* script-defined variable */
typedef struct PBox PBox;        /* A bounding box */

/* Compass points */
#define CP_C      0   /* Center of the object.  (Always PElem.ptAt) */
#define CP_N      1
#define CP_NE     2
#define CP_E      3
#define CP_SE     4
#define CP_S      5
#define CP_SW     6
#define CP_W      7
#define CP_NW     8

/* Heading angles corresponding to compass points */
static const PNum pik_hdg_angle[] = {
  /* C  */    0.0,
  /* N  */    0.0,
  /* NE */   45.0,
  /* E  */   90.0,
  /* SE */  135.0,
  /* S  */  180.0,
  /* SW */  225.0,
  /* W  */  270.0,
  /* NW */  315.0,
};

/* Built-in functions */
#define FN_ABS    0
#define FN_COS    1
#define FN_INT    2
#define FN_MAX    3
#define FN_MIN    4
#define FN_SIN    5
#define FN_SQRT   6

/* Text position and style flags.  Stored in PToken.eCode so limited
** to 15 bits. */
#define TP_LJUST   0x0001  /* left justify......          */
#define TP_RJUST   0x0002  /*            ...Right justify */
#define TP_JMASK   0x0003  /* Mask for justification bits */
#define TP_ABOVE2  0x0004  /* Position text way above PElem.ptAt */
#define TP_ABOVE   0x0008  /* Position text above PElem.ptAt */
#define TP_CENTER  0x0010  /* On the line */
#define TP_BELOW   0x0020  /* Position text below PElem.ptAt */
#define TP_BELOW2  0x0040  /* Position text way below PElem.ptAt */
#define TP_VMASK   0x007c  /* Mask for text positioning flags */
#define TP_ITALIC  0x1000  /* Italic font */
#define TP_BOLD    0x2000  /* Bold font */
#define TP_FMASK   0x3000  /* Mask for font style */
#define TP_ALIGN   0x4000  /* Rotate to align with the line */

/* An object to hold a position in 2-D space */
struct PPoint {
  PNum x, y;             /* X and Y coordinates */
};

/* A bounding box */
struct PBox {
  PPoint sw, ne;         /* Lower-left and top-right corners */
};

/* A variable created by the ID = EXPR construct of the PIKCHR script 
**
** PIKCHR (and PIC) scripts do not use many varaibles, so it is reasonable
** to store them all on a linked list.
*/
struct PVar {
  const char *zName;       /* Name of the variable */
  PNum val;                /* Value of the variable */
  PVar *pNext;             /* Next variable in a list of them all */
};

/* A single token in the parser input stream
*/
struct PToken {
  const char *z;             /* Pointer to the token text */
  unsigned int n;            /* Length of the token in bytes */
  short int eCode;           /* Auxiliary code */
  unsigned char eType;       /* The numeric parser code */
  unsigned char eEdge;       /* Corner value for corner keywords */
};

/* Return negative, zero, or positive if pToken is less then, equal to
** or greater than zero-terminated string z[]
*/
static int pik_token_eq(PToken *pToken, const char *z){
  int c = strncmp(pToken->z,z,pToken->n);
  if( c==0 && z[pToken->n]!=0 ) c = -1;
  return c;
}

/* Extra token types not generated by LEMON but needed by the
** tokenizer
*/
#define T_WHITESPACE 254     /* Whitespace of comments */
#define T_ERROR      255     /* Any text that is not a valid token */

/* Directions of movement */
#define DIR_RIGHT     0
#define DIR_DOWN      1
#define DIR_LEFT      2
#define DIR_UP        3
#define ValidDir(X)     ((X)>=0 && (X)<=3)
#define IsUpDown(X)     (((X)&1)==1)
#define IsLeftRight(X)  (((X)&1)==0)

/* Bitmask for the various attributes for PElem.  These bits are
** collected in PElem.mProp and PElem.mCalc to check for contraint
** errors. */
#define A_WIDTH         0x000001
#define A_HEIGHT        0x000002
#define A_RADIUS        0x000004
#define A_THICKNESS     0x000008
#define A_DASHED        0x000010 /* Includes "dotted" */
#define A_FILL          0x000020
#define A_COLOR         0x000040
#define A_ARROW         0x000080
#define A_TOP           0x000100
#define A_BOTTOM        0x000200
#define A_LEFT          0x000400
#define A_RIGHT         0x000800
#define A_CORNER        0x001000
#define A_FROM          0x002000
#define A_CW            0x004000
#define A_AT            0x008000


/* A single element */
struct PElem {
  const PClass *type;      /* Element type */
  PToken errTok;           /* Reference token for error messages */
  PPoint ptAt;             /* Reference point for the object */
  PPoint ptEnter, ptExit;  /* Entry and exit points */
  PEList *pSublist;        /* Substructure for [...] elements */
  char *zName;             /* Name assigned to this element */
  PNum w;                  /* width */
  PNum h;                  /* height */
  PNum rad;                /* radius */
  PNum sw;                 /* stroke width ("thinkness") */
  PNum dotted;             /* dotted:  <=0.0 for off */
  PNum dashed;             /* dashed:  <=0.0 for off */
  PNum fill;               /* fill color.  Negative for off */
  PNum color;              /* Stroke color */
  PNum top;                /* Top edge */
  PNum bottom;             /* Bottom edge */
  PNum left;               /* Left edge */
  PNum right;              /* Right edge */
  PPoint with;             /* Position constraint from WITH clause */
  char eWith;              /* Type of heading point on WITH clause */
  char cw;                 /* True for clockwise arc */
  char larrow;             /* Arrow at beginning */
  char rarrow;             /* Arrow at end */
  char bClose;             /* True if "close" is seen */
  char bChop;              /* True if "chop" is seen */
  unsigned char nTxt;      /* Number of text values */
  unsigned mProp;          /* Masks of properties set so far */
  unsigned mCalc;          /* Values computed from other constraints */
  PToken aTxt[5];          /* Text with .eCode holding TP flags */
  int iLayer;              /* Rendering order */
  int inDir, outDir;       /* Entry and exit directions */
  int nPath;               /* Number of path points */
  PPoint *aPath;           /* Array of path points */
  PBox bbox;               /* Bounding box */
};

/* A list of elements */
struct PEList {
  int n;          /* Number of elements in the list */
  int nAlloc;     /* Allocated slots in a[] */
  PElem **a;      /* Pointers to individual elements */
};

/* Each call to the pikchr() subroutine uses an instance of the following
** object to pass around context to all of its subroutines.
*/
struct Pik {
  unsigned nErr;           /* Number of errors seen */
  const char *zIn;         /* Input PIKCHR-language text.  zero-terminated */
  unsigned int nIn;        /* Number of bytes in zIn */
  char *zOut;              /* Result accumulates here */
  unsigned int nOut;       /* Bytes written to zOut[] so far */
  unsigned int nOutAlloc;  /* Space allocated to zOut[] */
  unsigned char eDir;      /* Current direction */
  PElem *cur;              /* Element under construction */
  PEList *list;            /* Element list under construction */
  PVar *pVar;              /* Application-defined variables */
  PBox bbox;               /* Bounding box around all elements */
                           /* Cache of layout values.  <=0.0 for unknown... */
  PNum rScale;                 /* Multiply to convert inches to pixels */
  PNum fontScale;              /* Scale fonts by this percent */
  PNum charWidth;              /* Character width */
  PNum charHeight;             /* Character height */
  PNum wArrow;                 /* Width of arrowhead at the fat end */
  PNum hArrow;                 /* Ht of arrowhead - dist from tip to fat end */
  int bLayoutVars;             /* True if cache is valid */
  char thenFlag;           /* True if "then" seen */
  const char *zClass;      /* Class name for the <svg> */
  int wSVG, hSVG;          /* Width and height of the <svg> */
  /* Paths for lines are constructed here first, then transferred into
  ** the PElem object at the end: */
  int nTPath;              /* Number of entries on aTPath[] */
  int mTPath;              /* For last entry, 1: x set,  2: y set */
  PPoint aTPath[1000];     /* Path under construction */
};

/*
** The behavior of an object class is defined by an instance of
** this structure. This it the "virtual method" table.
*/
struct PClass {
  const char *zName;                     /* Name of class */
  char isLine;                           /* True if a line class */
  void (*xInit)(Pik*,PElem*);            /* Initializer */
  void (*xNumProp)(Pik*,PElem*,PToken*); /* Value change notification */
  PPoint (*xChop)(PElem*,PPoint*);       /* Chopper */
  PPoint (*xOffset)(Pik*,PElem*,int);    /* Offset from center to edge point */
  void (*xFit)(Pik*,PElem*,PNum w,PNum h); /* Size to fit text */
  void (*xRender)(Pik*,PElem*);            /* Render */
};


/* Forward declarations */
static void pik_append(Pik*, const char*,int);
static void pik_append_text(Pik*,const char*,int,int);
static void pik_append_num(Pik*,const char*,PNum);
static void pik_append_point(Pik*,const char*,PPoint*);
static void pik_append_x(Pik*,const char*,PNum,const char*);
static void pik_append_y(Pik*,const char*,PNum,const char*);
static void pik_append_xy(Pik*,const char*,PNum,PNum);
static void pik_append_dis(Pik*,const char*,PNum,const char*);
static void pik_append_arc(Pik*,PNum,PNum,PNum,PNum);
static void pik_append_clr(Pik*,const char*,PNum,const char*);
static void pik_append_style(Pik*,PElem*);
static void pik_append_txt(Pik*,PElem*);
static void pik_draw_arrowhead(Pik*,PPoint*pFrom,PPoint*pTo,PElem*);
static void pik_chop(Pik*,PPoint*pFrom,PPoint*pTo,PNum);
static void pik_error(Pik*,PToken*,const char*);
static void pik_elist_free(Pik*,PEList*);
static void pik_elem_free(Pik*,PElem*);
static void pik_render(Pik*,PEList*);
static PEList *pik_elist_append(Pik*,PEList*,PElem*);
static PElem *pik_elem_new(Pik*,PToken*,PToken*,PEList*);
static void pik_set_direction(Pik*,int);
static void pik_elem_setname(Pik*,PElem*,PToken*);
static void pik_set_var(Pik*,PToken*,PNum,PToken*);
static PNum pik_value(Pik*,const char*,int,int*);
static PNum pik_lookup_color(Pik*,PToken*);
static PNum pik_get_var(Pik*,PToken*);
static PNum pik_atof(Pik*,PToken*);
static void pik_after_adding_attributes(Pik*,PElem*);
static void pik_elem_move(PElem*,PNum dx, PNum dy);
static void pik_elist_move(PEList*,PNum dx, PNum dy);
static void pik_set_numprop(Pik*,PToken*,PNum,PNum);
static void pik_set_dashed(Pik*,PToken*,PNum*);
static void pik_then(Pik*,PToken*,PElem*);
static void pik_add_direction(Pik*,PToken*,PNum*,int);
static void pik_evenwith(Pik*,PToken*,PPoint*);
static void pik_set_from(Pik*,PElem*,PToken*,PPoint*);
static void pik_add_to(Pik*,PElem*,PToken*,PPoint*);
static void pik_close_path(Pik*,PToken*);
static void pik_set_at(Pik*,PToken*,PPoint*,PToken*);
static short int pik_nth_value(Pik*,PToken*);
static PElem *pik_find_nth(Pik*,PElem*,PToken*);
static PElem *pik_find_byname(Pik*,PElem*,PToken*);
static PPoint pik_place_of_elem(Pik*,PElem*,PToken*);
static int pik_bbox_isempty(PBox*);
static void pik_bbox_init(PBox*);
static void pik_bbox_addbox(PBox*,PBox*);
static void pik_bbox_addpt(PBox*,PPoint*);
static void pik_bbox_addellipse(PBox*,PNum x,PNum y,PNum rx,PNum ry);
static void pik_add_txt(Pik*,PToken*,int);
static void pik_size_to_fit(Pik*,PToken*);
static int pik_text_position(Pik*,int,PToken*);
static PNum pik_property_of(Pik*,PElem*,PToken*);
static PNum pik_func(Pik*,PToken*,PNum,PNum);
static PPoint pik_position_between(Pik *p, PNum x, PPoint p1, PPoint p2);
static PPoint pik_position_at_angle(Pik *p, PNum dist, PNum r, PPoint pt);
static PPoint pik_position_at_hdg(Pik *p, PNum dist, PToken *pD, PPoint pt);
static void pik_same(Pik *p, PElem*, PToken*);
static PPoint pik_nth_vertex(Pik *p, PToken *pNth, PToken *pErr, PElem *pElem);
static PToken pik_next_semantic_token(Pik *p, PToken *pThis);
static void pik_compute_layout_settings(Pik*);


} // end %include

%name pik_parser
%token_prefix T_
%token_type {PToken}
%extra_context {Pik *p}

%fallback ID EDGEPT.

// precedence rules.
%left OF.
%left PLUS MINUS.
%left STAR SLASH PERCENT.
%right UMINUS.

%type element_list {PEList*}
%destructor element_list {pik_elist_free(p,$$);}
%type element {PElem*}
%destructor element {pik_elem_free(p,$$);}
%type unnamed_element {PElem*}
%destructor unnamed_element {pik_elem_free(p,$$);}
%type basetype {PElem*}
%destructor basetype {pik_elem_free(p,$$);}
%type expr {PNum}
%type numproperty {PToken}
%type edge {PToken}
%type direction {PToken}
%type dashproperty {PToken}
%type colorproperty {PToken}
%type locproperty {PToken}
%type position {PPoint}
%type place {PPoint}
%type object {PElem*}
%type objectname {PElem*}
%type nth {PToken}
%type textposition {int}
%type rvalue {PNum}
%type lvalue {PToken}
%type even {PToken}

%syntax_error {
  if( TOKEN.z && TOKEN.z[0] ){
    pik_error(p, &TOKEN, "syntax error");
  }else{
    pik_error(p, 0, "syntax error");
  }
}
%stack_overflow {
  pik_error(p, 0, "parser stack overflow");
}

document ::= element_list(X).  {pik_render(p,X);}


element_list(A) ::= element(X).   { A = pik_elist_append(p,0,X); }
element_list(A) ::= element_list(B) EOL element(X).
                      { A = pik_elist_append(p,B,X); }


element(A) ::= .   { A = 0; }
element(A) ::= direction(D).  { pik_set_direction(p,D.eCode);  A=0; }
element(A) ::= lvalue(N) ASSIGN(OP) rvalue(X). {pik_set_var(p,&N,X,&OP); A=0;}
element(A) ::= PLACENAME(N) COLON unnamed_element(X).
               { A = X;  pik_elem_setname(p,X,&N); }
element(A) ::= PLACENAME(N) COLON position(P).
               { A = pik_elem_new(p,0,0,0);
                 if(A){ A->ptAt = P; pik_elem_setname(p,A,&N); }}
element(A) ::= unnamed_element(X).  {A = X;}
element(A) ::= print prlist.  {pik_append(p,"<br>\n",5); A=0;}

lvalue(A) ::= ID(A).
lvalue(A) ::= FILL(A).
lvalue(A) ::= COLOR(A).
lvalue(A) ::= THICKNESS(A).

// PLACENAME might actually be a color name (ex: DarkBlue).  But we
// cannot make it part of expr due to parsing ambiguities.  The
// rvalue non-terminal means "general expression or a colorname"
rvalue(A) ::= expr(A).
rvalue(A) ::= PLACENAME(C).  {A = pik_lookup_color(p,&C);}

print ::= PRINT.
prlist ::= pritem.
prlist ::= prlist prsep pritem.
pritem ::= FILL(X).        {pik_append_num(p,"",pik_value(p,X.z,X.n,0));}
pritem ::= COLOR(X).       {pik_append_num(p,"",pik_value(p,X.z,X.n,0));}
pritem ::= THICKNESS(X).   {pik_append_num(p,"",pik_value(p,X.z,X.n,0));}
pritem ::= rvalue(X).      {pik_append_num(p,"",X);}
pritem ::= STRING(S). {pik_append_text(p,S.z+1,S.n-2,0);}
prsep  ::= COMMA. {pik_append(p, " ", 1);}

unnamed_element(A) ::= basetype(X) attribute_list.  
                          {A = X; pik_after_adding_attributes(p,A);}

basetype(A) ::= CLASSNAME(N).            {A = pik_elem_new(p,&N,0,0); }
basetype(A) ::= STRING(N) textposition(P).
                            {N.eCode = P; A = pik_elem_new(p,0,&N,0); }
basetype(A) ::= LB savelist(L) element_list(X) RB(E).
      { p->list = L; A = pik_elem_new(p,0,0,X); if(A) A->errTok = E; }

%type savelist {PEList*}
// No distructor required as this same PEList is also held by
// an "element" non-terminal deeper on the stack.
savelist(A) ::= .   {A = p->list; p->list = 0;}

direction(A) ::= UP(A).
direction(A) ::= DOWN(A).
direction(A) ::= LEFT(A).
direction(A) ::= RIGHT(A).

attribute_list ::= expr(X).           { pik_add_direction(p,0,&X,0);}
attribute_list ::= expr(X) PERCENT.   { pik_add_direction(p,0,&X,1);}
attribute_list ::= alist.
alist ::=.
alist ::= alist attribute.
attribute ::= numproperty(P) expr(X) PERCENT.
                                      { pik_set_numprop(p,&P,0.0,X/100.0); }
attribute ::= numproperty(P) expr(X). { pik_set_numprop(p,&P,X,0.0); }
attribute ::= dashproperty(P) expr(X).  { pik_set_dashed(p,&P,&X); }
attribute ::= dashproperty(P).          { pik_set_dashed(p,&P,0);  }
attribute ::= colorproperty(P) rvalue(X). { pik_set_numprop(p,&P,X,0.0); }
attribute ::= direction(D) expr(X) PERCENT.
                                    { pik_add_direction(p,&D,&X,1);}
attribute ::= direction(D) expr(X). { pik_add_direction(p,&D,&X,0);}
attribute ::= direction(D).         { pik_add_direction(p,&D,0,0); }
attribute ::= direction(D) even position(P). {pik_evenwith(p,&D,&P);}
attribute ::= CLOSE(E).             { pik_close_path(p,&E); }
attribute ::= CHOP.                 { p->cur->bChop = 1; }
attribute ::= FROM(T) position(X).  { pik_set_from(p,p->cur,&T,&X); }
attribute ::= TO(T) position(X).    { pik_add_to(p,p->cur,&T,&X); }
attribute ::= THEN(T).              { pik_then(p, &T, p->cur); }
attribute ::= boolproperty.
attribute ::= AT(A) position(P).                    { pik_set_at(p,0,&P,&A); }
attribute ::= WITH withclause.
attribute ::= SAME(E).                          {pik_same(p,0,&E);}
attribute ::= SAME(E) AS object(X).             {pik_same(p,X,&E);}
attribute ::= STRING(T) textposition(P).        {pik_add_txt(p,&T,P);}
attribute ::= FIT(E).                           {pik_size_to_fit(p,&E); }

even ::= UNTIL EVEN WITH.
even ::= EVEN WITH.

withclause ::= with.
withclause ::= withclause AND with.
with ::=  DOT_E edge(E) AT(A) position(P).{ pik_set_at(p,&E,&P,&A); }
with ::=  edge(E) AT(A) position(P).      { pik_set_at(p,&E,&P,&A); }

// Properties that require an argument
numproperty(A) ::= HEIGHT|WIDTH|RADIUS|DIAMETER|THICKNESS(P).  {A = P;}

// Properties with optional arguments
dashproperty(A) ::= DOTTED(A).
dashproperty(A) ::= DASHED(A).

// Color properties
colorproperty(A) ::= FILL(A).
colorproperty(A) ::= COLOR(A).

// Properties with no argument
boolproperty ::= CW.          {p->cur->cw = 1;}
boolproperty ::= CCW.         {p->cur->cw = 0;}
boolproperty ::= LARROW.      {p->cur->larrow=1; p->cur->rarrow=0; }
boolproperty ::= RARROW.      {p->cur->larrow=0; p->cur->rarrow=1; }
boolproperty ::= LRARROW.     {p->cur->larrow=1; p->cur->rarrow=1; }
boolproperty ::= INVIS.       {p->cur->sw = 0.0;}

textposition(A) ::= .   {A = 0;}
textposition(A) ::= textposition(B) 
   CENTER|LJUST|RJUST|ABOVE|BELOW|ITALIC|BOLD|ALIGNED(F).
                        {A = pik_text_position(p,B,&F);}


position(A) ::= expr(X) COMMA expr(Y).                {A.x=X; A.y=Y;}
position(A) ::= place(A).
position(A) ::= place(B) PLUS expr(X) COMMA expr(Y).  {A.x=B.x+X; A.y=B.y+Y;}
position(A) ::= place(B) MINUS expr(X) COMMA expr(Y). {A.x=B.x-X; A.y=B.y-Y;}
position(A) ::= place(B) PLUS LP expr(X) COMMA expr(Y) RP.
                                                      {A.x=B.x+X; A.y=B.y+Y;}
position(A) ::= place(B) MINUS LP expr(X) COMMA expr(Y) RP.
                                                      {A.x=B.x-X; A.y=B.y-Y;}
position(A) ::= LP position(X) COMMA position(Y) RP.  {A.x=X.x; A.y=Y.y;}
position(A) ::= LP position(X) RP.                    {A=X;}
position(A) ::= expr(X) between position(P1) AND position(P2).
                                       {A = pik_position_between(p,X,P1,P2);}
position(A) ::= expr(X) ABOVE position(B).    {A=B; A.y += X;}
position(A) ::= expr(X) BELOW position(B).    {A=B; A.y -= X;}
position(A) ::= expr(X) LEFT OF position(B).  {A=B; A.x -= X;}
position(A) ::= expr(X) RIGHT OF position(B). {A=B; A.x += X;}
position(A) ::= expr(D) EDGEPT(E) OF position(P).
                                        {A = pik_position_at_hdg(p,D,&E,P);}
position(A) ::= expr(D) HEADING expr(G) FROM position(P).
                                        {A = pik_position_at_angle(p,D,G,P);}

between ::= WAY BETWEEN.
between ::= BETWEEN.
between ::= OF THE WAY BETWEEN.

place(A) ::= object(O).                 {A = pik_place_of_elem(p,O,0);}
place(A) ::= object(O) DOT_E edge(X).   {A = pik_place_of_elem(p,O,&X);}
place(A) ::= object(O) DOT_L START(X).  {A = pik_place_of_elem(p,O,&X);}
place(A) ::= object(O) DOT_L END(X).    {A = pik_place_of_elem(p,O,&X);}
place(A) ::= START(X) OF object(O).     {A = pik_place_of_elem(p,O,&X);}
place(A) ::= END(X) OF object(O).       {A = pik_place_of_elem(p,O,&X);}
place(A) ::= edge(X) OF object(O).      {A = pik_place_of_elem(p,O,&X);}
place(A) ::= NTH(N) VERTEX(E) OF object(X). {A = pik_nth_vertex(p,&N,&E,X);}

object(A) ::= objectname(A).
object(A) ::= nth(N).                     {A = pik_find_nth(p,0,&N);}
object(A) ::= nth(N) OF|IN object(B).     {A = pik_find_nth(p,B,&N);}

objectname(A) ::= PLACENAME(N).           {A = pik_find_byname(p,0,&N);}
objectname(A) ::= objectname(B) DOT_U PLACENAME(N).
                                          {A = pik_find_byname(p,B,&N);}

nth(A) ::= NTH(N) CLASSNAME(ID).     {A=ID; A.eCode = pik_nth_value(p,&N); }
nth(A) ::= NTH(N) LAST CLASSNAME(ID). {A=ID; A.eCode = -pik_nth_value(p,&N); }
nth(A) ::= LAST CLASSNAME(ID).       {A=ID; A.eCode = -1;}
nth(A) ::= LAST(ID).                 {A=ID; A.eCode = -1;}
nth(A) ::= NTH(N) LB(ID) RB.         {A=ID; A.eCode = pik_nth_value(p,&N);}
nth(A) ::= NTH(N) LAST LB(ID) RB.    {A=ID; A.eCode = -pik_nth_value(p,&N);}
nth(A) ::= LAST LB(ID) RB.           {A=ID; A.eCode = -1; }

expr(A) ::= expr(X) PLUS expr(Y).     {A=X+Y;}
expr(A) ::= expr(X) MINUS expr(Y).    {A=X-Y;}
expr(A) ::= expr(X) STAR expr(Y).     {A=X*Y;}
expr(A) ::= expr(X) SLASH(E) expr(Y).    {
  if( Y==0.0 ){ pik_error(p, &E, "division by zero"); A = 0.0; }
  else{ A = X/Y; }
}
expr(A) ::= MINUS expr(X). [UMINUS]  {A=-X;}
expr(A) ::= PLUS expr(X). [UMINUS]   {A=X;}
expr(A) ::= LP expr(X) RP.           {A=X;}
expr(A) ::= NUMBER(N).               {A=pik_atof(p,&N);}
expr(A) ::= ID(N).                   {A=pik_get_var(p,&N);}
expr(A) ::= FUNC1(F) LP expr(X) RP.               {A = pik_func(p,&F,X,0.0);}
expr(A) ::= FUNC2(F) LP expr(X) COMMA expr(Y) RP. {A = pik_func(p,&F,X,Y);}

expr(A) ::= object(O) DOT_L locproperty(P).    {A=pik_property_of(p,O,&P);}
expr(A) ::= object(O) DOT_L numproperty(P).    {A=pik_property_of(p,O,&P);}
expr(A) ::= object(O) DOT_L dashproperty(P).   {A=pik_property_of(p,O,&P);}
expr(A) ::= object(O) DOT_L colorproperty(P).  {A=pik_property_of(p,O,&P);}
expr(A) ::= object(O) DOT_E edge(E) DOT_L X.   {A=pik_place_of_elem(p,O,&E).x;}
expr(A) ::= object(O) DOT_E edge(E) DOT_L Y.   {A=pik_place_of_elem(p,O,&E).y;}
expr(A) ::= LP locproperty(P) OF object(O) RP.   {A=pik_property_of(p,O,&P);}
expr(A) ::= LP dashproperty(P) OF object(O) RP.  {A=pik_property_of(p,O,&P);}
expr(A) ::= LP numproperty(P) OF object(O) RP.   {A=pik_property_of(p,O,&P);}
expr(A) ::= LP colorproperty(P) OF object(O) RP. {A=pik_property_of(p,O,&P);}

expr(A) ::= NTH(N) VERTEX(E) OF object(X) DOT_L X.
                                             {A = pik_nth_vertex(p,&N,&E,X).x;}
expr(A) ::= NTH(N) VERTEX(E) OF object(X) DOT_L Y.
                                             {A = pik_nth_vertex(p,&N,&E,X).y;}

locproperty(A) ::= X|Y(A).

edge(A) ::= EDGEPT(A).
edge(A) ::= TOP(A).
edge(A) ::= BOTTOM(A).
edge(A) ::= LEFT(A).
edge(A) ::= RIGHT(A).

%code {


/* Chart of the 140 official HTML color names with their
** corresponding RGB value.
**
** Two new names "None" and "Off" are added with a value
** of -1.
*/
static const struct {
  const char *zName;  /* Name of the color */
  int val;            /* RGB value */
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
  { "None",                              -1 },  /* Non-standard addition */
  { "Off",                               -1 },  /* Non-standard addition */
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

/* Built-in variable names.
**
** This array is constant.  When a script changes the value of one of
** these built-ins, a new PVar record is added at the head of
** the Pik.pVar list, which is searched first.  Thus the new PVar entry
** will override this default value.
**
** Units are in inches, except for "color" and "fill" which are 
** interpreted as 24-bit RGB values.
**
** Binary search used.  Must be kept in sorted order.
*/
static const struct { const char *zName; PNum val; } aBuiltin[] = {
  { "arcrad",      0.25  },
  { "arrowhead",   2.0   },
  { "arrowht",     0.1   },
  { "arrowwid",    0.05  },
  { "boxht",       0.5   },
  { "boxrad",      0.0   },
  { "boxwid",      0.75  },
  { "charht",      0.14  },
  { "charwid",     0.08  },
  { "circlerad",   0.25  },
  { "color",       0.0   },
  { "cylht",       0.5   },
  { "cylrad",      0.075 },
  { "cylwid",      0.75  },
  { "dashwid",     0.05  },
  { "dotrad",      0.015 },
  { "ellipseht",   0.5   },
  { "ellipsewid",  0.75  },
  { "fill",        -1.0  },
  { "lineht",      0.5   },
  { "linewid",     0.5   },
  { "movewid",     0.5   },
  { "ovalht",      0.5   },
  { "ovalwid",     1.0   },
  { "scale",       1.0   },
  { "textht",      0.5   },
  { "textwid",     0.75  },
  { "thickness",   0.015 },
};


/* Methods for the "arc" class */
static void arcInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "arcrad",6,0);
  pElem->h = pElem->w;
}
/* Hack: Arcs are here rendered as quadratic Bezier curves rather
** than true arcs.  Multiple reasons: (1) the legacy-PIC parameters
** that control arcs are obscure and I could not figure out what they
** mean based on available documentation.  (2) Arcs are rarely used,
** and so do not seem that important.
*/
static void arcRender(Pik *p, PElem *pElem){
  PNum dx, dy;
  PPoint f, m, t;
  if( pElem->nPath<2 ) return;
  if( pElem->sw<=0.0 ) return;
  f = pElem->aPath[0];
  t = pElem->aPath[1];
  m.x = 0.5*(f.x+t.x);
  m.y = 0.5*(f.y+t.y);
  dx = t.x - f.x;
  dy = t.y - f.y;
  if( pElem->cw ){
    m.x -= 0.4*dy;
    m.y += 0.4*dx;
  }else{
    m.x += 0.4*dy;
    m.y -= 0.4*dx;
  }
  if( pElem->larrow ){
    pik_draw_arrowhead(p,&m,&f,pElem);
  }
  if( pElem->rarrow ){
    pik_draw_arrowhead(p,&m,&t,pElem);
  }
  pik_append_xy(p,"<path d=\"M", f.x, f.y);
  pik_append_xy(p,"Q", m.x, m.y);
  pik_append_xy(p," ", t.x, t.y);
  pik_append(p,"\" ",2);
  pik_append_style(p,pElem);
  pik_append(p,"\" />\n", -1);

  pik_append_txt(p, pElem);
}


/* Methods for the "arrow" class */
static void arrowInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "linewid",7,0);
  pElem->h = pik_value(p, "lineht",6,0);
  pElem->rad = pik_value(p, "linerad",7,0);
  pElem->fill = -1.0;
  pElem->rarrow = 1;
}

/* Methods for the "box" class */
static void boxInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "boxwid",6,0);
  pElem->h = pik_value(p, "boxht",5,0);
  pElem->rad = pik_value(p, "boxrad",6,0);
}
/* Return offset from the center of the box to the compass point 
** given by parameter cp */
static PPoint boxOffset(Pik *p, PElem *pElem, int cp){
  PPoint pt;
  PNum w2 = 0.5*pElem->w;
  PNum h2 = 0.5*pElem->h;
  PNum rad = pElem->rad;
  PNum rx;
  if( rad<=0.0 ){
    rx = 0.0;
  }else{
    if( rad>w2 ) rad = w2;
    if( rad>h2 ) rad = h2;
    rx = 0.29289321881345252392*rad;
  }
  pt.x = pt.y = 0.0;
  switch( cp ){
    case CP_C:   pt.x = 0.0;      pt.y = 0.0;    break;
    case CP_N:   pt.x = 0.0;      pt.y = h2;     break;
    case CP_NE:  pt.x = w2-rx;    pt.y = h2-rx;  break;
    case CP_E:   pt.x = w2;       pt.y = 0.0;    break;
    case CP_SE:  pt.x = w2-rx;    pt.y = rx-h2;  break;
    case CP_S:   pt.x = 0.0;      pt.y = -h2;    break;
    case CP_SW:  pt.x = rx-w2;    pt.y = rx-h2;  break;
    case CP_W:   pt.x = -w2;      pt.y = 0.0;    break;
    case CP_NW:  pt.x = rx-w2;    pt.y = h2-rx;  break;
  }
  return pt;
}
static PPoint boxChop(PElem *pElem, PPoint *pPt){
  PNum dx, dy;
  int cp = CP_C;
  PPoint chop = pElem->ptAt;
  if( pElem->w<=0.0 ) return chop;
  if( pElem->h<=0.0 ) return chop;
  dx = (pPt->x - pElem->ptAt.x)*pElem->h/pElem->w;
  dy = (pPt->y - pElem->ptAt.y);
  if( dx>0.0 ){
    if( dy>=2.414*dx ){
      cp = CP_N;
    }else if( dy>=0.414*dx ){
      cp = CP_NE;
    }else if( dy>=-0.414*dx ){
      cp = CP_E;
    }else if( dy>-2.414*dx ){
      cp = CP_SE;
    }else{
      cp = CP_S;
    }
  }else{
    if( dy>=-2.414*dx ){
      cp = CP_N;
    }else if( dy>=-0.414*dx ){
      cp = CP_NW;
    }else if( dy>=0.414*dx ){
      cp = CP_W;
    }else if( dy>2.414*dx ){
      cp = CP_SW;
    }else{
      cp = CP_S;
    }
  }
  chop = pElem->type->xOffset(0,pElem,cp);
  chop.x += pElem->ptAt.x;
  chop.y += pElem->ptAt.y;
  return chop;
}
static void boxFit(Pik *p, PElem *pElem, PNum w, PNum h){
  if( w>0 ) pElem->w = w;
  if( h>0 ) pElem->h = h;
}
static void boxRender(Pik *p, PElem *pElem){
  PNum w2 = 0.5*pElem->w;
  PNum h2 = 0.5*pElem->h;
  PNum rad = pElem->rad;
  PPoint pt = pElem->ptAt;
  if( pElem->sw>0.0 ){
    if( rad<=0.0 ){
      pik_append_xy(p,"<path d=\"M", pt.x-w2,pt.y-h2);
      pik_append_xy(p,"L", pt.x+w2,pt.y-h2);
      pik_append_xy(p,"L", pt.x+w2,pt.y+h2);
      pik_append_xy(p,"L", pt.x-w2,pt.y+h2);
      pik_append(p,"Z\" ",-1);
    }else{
      /*
      **         ----       - y3
      **        /    \
      **       /      \     _ y2
      **      |        |    
      **      |        |    _ y1
      **       \      /
      **        \    /
      **         ----       _ y0
      **
      **      '  '  '  '
      **     x0 x1 x2 x3
      */
      PNum x0,x1,x2,x3,y0,y1,y2,y3;
      if( rad>w2 ) rad = w2;
      if( rad>h2 ) rad = h2;
      x0 = pt.x - w2;
      x1 = x0 + rad;
      x3 = pt.x + w2;
      x2 = x3 - rad;
      y0 = pt.y - h2;
      y1 = y0 + rad;
      y3 = pt.y + h2;
      y2 = y3 - rad;
      pik_append_xy(p,"<path d=\"M", x1, y0);
      if( x2>x1 ) pik_append_xy(p, "L", x2, y0);
      pik_append_arc(p, rad, rad, x3, y1);
      if( y2>y1 ) pik_append_xy(p, "L", x3, y2);
      pik_append_arc(p, rad, rad, x2, y3);
      if( x2>x1 ) pik_append_xy(p, "L", x1, y3);
      pik_append_arc(p, rad, rad, x0, y2);
      if( y2>y1 ) pik_append_xy(p, "L", x0, y1);
      pik_append_arc(p, rad, rad, x1, y0);
      pik_append(p,"Z\" ",-1);
    }
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}

/* Methods for the "circle" class */
static void circleInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "circlerad",9,0)*2;
  pElem->h = pElem->w;
  pElem->rad = 0.5*pElem->w;
}
static void circleNumProp(Pik *p, PElem *pElem, PToken *pId){
  /* For a circle, the width must equal the height and both must
  ** be twice the radius.  Enforce those constraints. */
  switch( pId->eType ){
    case T_RADIUS:
      pElem->w = pElem->h = 2.0*pElem->rad;
      break;
    case T_WIDTH:
      pElem->h = pElem->w;
      pElem->rad = 0.5*pElem->w;
      break;
    case T_HEIGHT:
      pElem->w = pElem->h;
      pElem->rad = 0.5*pElem->w;
      break;
  }
}
static PPoint circleChop(PElem *pElem, PPoint *pPt){
  PPoint chop;
  PNum dx = pPt->x - pElem->ptAt.x;
  PNum dy = pPt->y - pElem->ptAt.y;
  PNum dist = sqrt(dx*dx + dy*dy);
  if( dist<pElem->rad ) return pElem->ptAt;
  chop.x = pElem->ptAt.x + dx*pElem->rad/dist;
  chop.y = pElem->ptAt.y + dy*pElem->rad/dist;
  return chop;
}
static void circleFit(Pik *p, PElem *pElem, PNum w, PNum h){
  PNum mx = 0.0;
  if( w>0 ) mx = w;
  if( h>mx ) mx = h;
  if( (w*w + h*h) > mx*mx ){
    mx = sqrt(w*w + h*h);
  }
  if( mx>0.0 ){
    pElem->rad = 0.5*mx;
    pElem->w = pElem->h = mx;
  }
}

static void circleRender(Pik *p, PElem *pElem){
  PNum r = pElem->rad;
  PPoint pt = pElem->ptAt;
  if( pElem->sw>0.0 ){
    pik_append_x(p,"<circle cx=\"", pt.x, "\"");
    pik_append_y(p," cy=\"", pt.y, "\"");
    pik_append_dis(p," r=\"", r, "\" ");
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}

/* Methods for the "cylinder" class */
static void cylinderInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "cylwid",6,0);
  pElem->h = pik_value(p, "cylht",5,0);
  pElem->rad = pik_value(p, "cylrad",6,0); /* Minor radius of ellipses */
}
static void cylinderRender(Pik *p, PElem *pElem){
  PNum w2 = 0.5*pElem->w;
  PNum h2 = 0.5*pElem->h;
  PNum rad = pElem->rad;
  PPoint pt = pElem->ptAt;
  if( pElem->sw>0.0 ){
    pik_append_xy(p,"<path d=\"M", pt.x-w2,pt.y+h2-rad);
    pik_append_xy(p,"L", pt.x-w2,pt.y-h2+rad);
    pik_append_arc(p,w2,rad,pt.x+w2,pt.y-h2+rad);
    pik_append_xy(p,"L", pt.x+w2,pt.y+h2-rad);
    pik_append_arc(p,w2,rad,pt.x-w2,pt.y+h2-rad);
    pik_append_arc(p,w2,rad,pt.x+w2,pt.y+h2-rad);
    pik_append(p,"\" ",-1);
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}
static PPoint cylinderOffset(Pik *p, PElem *pElem, int cp){
  PPoint pt;
  PNum w2 = pElem->w*0.5;
  PNum h1 = pElem->h*0.5;
  PNum h2 = h1 - pElem->rad;
  switch( cp ){
    case CP_C:   pt.x = 0.0;   pt.y = 0.0;    break;
    case CP_N:   pt.x = 0.0;   pt.y = h1;     break;
    case CP_NE:  pt.x = w2;    pt.y = h2;     break;
    case CP_E:   pt.x = w2;    pt.y = 0.0;    break;
    case CP_SE:  pt.x = w2;    pt.y = -h2;    break;
    case CP_S:   pt.x = 0.0;   pt.y = -h1;    break;
    case CP_SW:  pt.x = -w2;   pt.y = -h2;    break;
    case CP_W:   pt.x = -w2;   pt.y = 0.0;    break;
    case CP_NW:  pt.x = -w2;   pt.y = h2;     break;
  }
  return pt;
}

/* Methods for the "dot" class */
static void dotInit(Pik *p, PElem *pElem){
  pElem->rad = pik_value(p, "dotrad",6,0);
  pElem->h = pElem->w = pElem->rad*6;
  pElem->fill = pElem->color;
}
static void dotNumProp(Pik *p, PElem *pElem, PToken *pId){
  switch( pId->eType ){
    case T_COLOR:
      pElem->fill = pElem->color;
      break;
    case T_FILL:
      pElem->color = pElem->fill;
      break;
  }
}
static void dotRender(Pik *p, PElem *pElem){
  PNum r = pElem->rad;
  PPoint pt = pElem->ptAt;
  if( pElem->sw>0.0 ){
    pik_append_x(p,"<circle cx=\"", pt.x, "\"");
    pik_append_y(p," cy=\"", pt.y, "\"");
    pik_append_dis(p," r=\"", r, "\"");
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}



/* Methods for the "ellipse" class */
static void ellipseInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "ellipsewid",10,0);
  pElem->h = pik_value(p, "ellipseht",9,0);
}
static PPoint ellipseChop(PElem *pElem, PPoint *pPt){
  PPoint chop;
  PNum s, dq, dist;
  PNum dx = pPt->x - pElem->ptAt.x;
  PNum dy = pPt->y - pElem->ptAt.y;
  if( pElem->w<=0.0 ) return pElem->ptAt;
  if( pElem->h<=0.0 ) return pElem->ptAt;
  s = pElem->h/pElem->w;
  dq = dx*s;
  dist = sqrt(dq*dq + dy*dy);
  if( dist<pElem->h ) return pElem->ptAt;
  chop.x = pElem->ptAt.x + 0.5*dq*pElem->h/(dist*s);
  chop.y = pElem->ptAt.y + 0.5*dy*pElem->h/dist;
  return chop;
}
static PPoint ellipseOffset(Pik *p, PElem *pElem, int cp){
  PPoint pt;
  PNum w = pElem->w*0.5;
  PNum w2 = w*0.70710678118654747608;
  PNum h = pElem->h*0.5;
  PNum h2 = h*0.70710678118654747608;
  switch( cp ){
    case CP_C:   pt.x = 0.0;   pt.y = 0.0;    break;
    case CP_N:   pt.x = 0.0;   pt.y = h;      break;
    case CP_NE:  pt.x = w2;    pt.y = h2;     break;
    case CP_E:   pt.x = w;     pt.y = 0.0;    break;
    case CP_SE:  pt.x = w2;    pt.y = -h2;    break;
    case CP_S:   pt.x = 0.0;   pt.y = -h;     break;
    case CP_SW:  pt.x = -w2;   pt.y = -h2;    break;
    case CP_W:   pt.x = -w;    pt.y = 0.0;    break;
    case CP_NW:  pt.x = -w2;   pt.y = h2;     break;
  }
  return pt;
}
static void ellipseRender(Pik *p, PElem *pElem){
  PNum w = pElem->w;
  PNum h = pElem->h;
  PPoint pt = pElem->ptAt;
  if( pElem->sw>0.0 ){
    pik_append_x(p,"<ellipse cx=\"", pt.x, "\"");
    pik_append_y(p," cy=\"", pt.y, "\"");
    pik_append_dis(p," rx=\"", w/2.0, "\"");
    pik_append_dis(p," ry=\"", h/2.0, "\" ");
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}

/* Methods for the "line" class */
static void lineInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "linewid",7,0);
  pElem->h = pik_value(p, "lineht",6,0);
  pElem->rad = pik_value(p, "linerad",7,0);
  pElem->fill = -1.0;
}
static void lineRender(Pik *p, PElem *pElem){
  int i;
  if( pElem->sw>0.0 ){
    const char *z = "<path d=\"M";
    int n = pElem->nPath;
    if( pElem->larrow ){
      pik_draw_arrowhead(p,&pElem->aPath[1],&pElem->aPath[0],pElem);
    }
    if( pElem->rarrow ){
      pik_draw_arrowhead(p,&pElem->aPath[n-2],&pElem->aPath[n-1],pElem);
    }
    for(i=0; i<pElem->nPath; i++){
      pik_append_xy(p,z,pElem->aPath[i].x,pElem->aPath[i].y);
      z = "L";
    }
    if( pElem->bClose ){
      pik_append(p,"Z",1);
    }else{
      pElem->fill = -1.0;
    }
    pik_append(p,"\" ",-1);
    pik_append_style(p,pElem);
    pik_append(p,"\" />\n", -1);
  }
  pik_append_txt(p, pElem);
}

/* Methods for the "move" class */
static void moveInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "movewid",7,0);
  pElem->h = pElem->w;
  pElem->fill = -1.0;
  pElem->color = -1.0;
  pElem->sw = -1.0;
}
static void moveRender(Pik *p, PElem *pElem){
  /* No-op */
}

/* Methods for the "oval" class */
static void ovalInit(Pik *p, PElem *pElem){
  pElem->h = pik_value(p, "ovalht",6,0);
  pElem->w = pik_value(p, "ovalwid",7,0);
  pElem->rad = 0.5*(pElem->h<pElem->w?pElem->h:pElem->w);
}
static void ovalNumProp(Pik *p, PElem *pElem, PToken *pId){
  /* Always adjust the radius to be half of the smaller of
  ** the width and height. */
  pElem->rad = 0.5*(pElem->h<pElem->w?pElem->h:pElem->w);
}
static void ovalFit(Pik *p, PElem *pElem, PNum w, PNum h){
  if( w>0 ) pElem->w = w;
  if( h>0 ) pElem->h = h;
  if( pElem->w<pElem->h ) pElem->w = pElem->h;
}



/* Methods for the "spline" class */
static void splineInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "linewid",7,0);
  pElem->h = pik_value(p, "lineht",6,0);
  pElem->rad = 1000;
  pElem->fill = -1.0;  /* Disable fill by default */
}
/* Return a point along the path from "f" to "t" that is r units
** prior to reach "t", except if the path is less than 2*r total,
** return the midpoint.
*/
static PPoint radiusMidpoint(PPoint f, PPoint t, PNum r, int *pbMid){
  PNum dx = t.x - f.x;
  PNum dy = t.y - f.y;
  PNum dist = sqrt(dx*dx+dy*dy);
  PPoint m;
  if( dist<=0.0 ) return t;
  dx /= dist;
  dy /= dist;
  if( r > 0.5*dist ){
    r = 0.5*dist;
    *pbMid = 1;
  }else{
    *pbMid = 0;
  }
  m.x = t.x - r*dx;
  m.y = t.y - r*dy;
  return m;
}
static void radiusPath(Pik *p, PElem *pElem, PNum r){
  int i;
  int n = pElem->nPath;
  const PPoint *a = pElem->aPath;
  PPoint m;
  int isMid = 0;

  pik_append_xy(p,"<path d=\"M", a[0].x, a[0].y);
  m = radiusMidpoint(a[0], a[1], r, &isMid);
  pik_append_xy(p," L ",m.x,m.y);
  for(i=1; i<n-1; i++){
    m = radiusMidpoint(a[i+1],a[i],r, &isMid);
    pik_append_xy(p," Q ",a[i].x,a[i].y);
    pik_append_xy(p," ",m.x,m.y);
    if( !isMid ){
      m = radiusMidpoint(a[i],a[i+1],r, &isMid);
      pik_append_xy(p," L ",m.x,m.y);
    }
  }
  pik_append_xy(p," L ",a[i].x,a[i].y);
  pik_append(p,"\" ",-1);
  pik_append_style(p,pElem);
  pik_append(p,"\" />\n", -1);
}
static void splineRender(Pik *p, PElem *pElem){
  if( pElem->sw>0.0 ){
    int n = pElem->nPath;
    PNum r = pElem->rad;
    if( n<3 || r<=0.0 ){
      lineRender(p,pElem);
      return;
    }
    if( pElem->larrow ){
      pik_draw_arrowhead(p,&pElem->aPath[1],&pElem->aPath[0],pElem);
    }
    if( pElem->rarrow ){
      pik_draw_arrowhead(p,&pElem->aPath[n-2],&pElem->aPath[n-1],pElem);
    }
    radiusPath(p,pElem,pElem->rad);
  }
  pik_append_txt(p, pElem);
}


/* Methods for the "text" class */
static void textInit(Pik *p, PElem *pElem){
  pElem->w = pik_value(p, "textwid",7,0);
  pElem->h = pik_value(p, "textht",6,0);
  pElem->sw = 0.0;
}

/* Methods for the "sublist" class */
static void sublistInit(Pik *p, PElem *pElem){
  PEList *pList = pElem->pSublist;
  int i;
  pik_bbox_init(&pElem->bbox);
  for(i=0; i<pList->n; i++){
    pik_bbox_addbox(&pElem->bbox, &pList->a[i]->bbox);
  }
  pElem->w = pElem->bbox.ne.x - pElem->bbox.sw.x;
  pElem->h = pElem->bbox.ne.y - pElem->bbox.sw.y;
  pElem->ptAt.x = 0.5*(pElem->bbox.ne.x + pElem->bbox.sw.x);
  pElem->ptAt.y = 0.5*(pElem->bbox.ne.y + pElem->bbox.sw.y);
  pElem->mCalc |= A_WIDTH|A_HEIGHT;
}


/*
** The following array holds all the different kinds of named
** elements.  The special STRING and [] elements are separate.
*/
static const PClass aClass[] = {
   {  /* name */          "arc",
      /* isline */        1,
      /* xInit */         arcInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       arcRender
   },
   {  /* name */          "arrow",
      /* isline */        1,
      /* xInit */         arrowInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       splineRender 
   },
   {  /* name */          "box",
      /* isline */        0,
      /* xInit */         boxInit,
      /* xNumProp */      0,
      /* xChop */         boxChop,
      /* xOffset */       boxOffset,
      /* xFit */          boxFit,
      /* xRender */       boxRender 
   },
   {  /* name */          "circle",
      /* isline */        0,
      /* xInit */         circleInit,
      /* xNumProp */      circleNumProp,
      /* xChop */         circleChop,
      /* xOffset */       ellipseOffset,
      /* xFit */          circleFit,
      /* xRender */       circleRender 
   },
   {  /* name */          "cylinder",
      /* isline */        0,
      /* xInit */         cylinderInit,
      /* xNumProp */      0,
      /* xChop */         boxChop,
      /* xOffset */       cylinderOffset,
      /* xFit */          0,
      /* xRender */       cylinderRender
   },
   {  /* name */          "dot",
      /* isline */        0,
      /* xInit */         dotInit,
      /* xNumProp */      dotNumProp,
      /* xChop */         circleChop,
      /* xOffset */       ellipseOffset,
      /* xFit */          0,
      /* xRender */       dotRender 
   },
   {  /* name */          "ellipse",
      /* isline */        0,
      /* xInit */         ellipseInit,
      /* xNumProp */      0,
      /* xChop */         ellipseChop,
      /* xOffset */       ellipseOffset,
      /* xFit */          0,
      /* xRender */       ellipseRender
   },
   {  /* name */          "line",
      /* isline */        1,
      /* xInit */         lineInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       splineRender
   },
   {  /* name */          "move",
      /* isline */        1,
      /* xInit */         moveInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       moveRender
   },
   {  /* name */          "oval",
      /* isline */        0,
      /* xInit */         ovalInit,
      /* xNumProp */      ovalNumProp,
      /* xChop */         boxChop,
      /* xOffset */       boxOffset,
      /* xFit */          ovalFit,
      /* xRender */       boxRender
   },
   {  /* name */          "spline",
      /* isline */        1,
      /* xInit */         splineInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       splineRender
   },
   {  /* name */          "text",
      /* isline */        0,
      /* xInit */         textInit,
      /* xNumProp */      0,
      /* xChop */         boxChop,
      /* xOffset */       boxOffset,
      /* xFit */          0,
      /* xRender */       boxRender 
   },
};
static const PClass sublistClass = 
   {  /* name */          "[]",
      /* isline */        0,
      /* xInit */         sublistInit,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       0 
   };
static const PClass noopClass = 
   {  /* name */          "noop",
      /* isline */        0,
      /* xInit */         0,
      /* xNumProp */      0,
      /* xChop */         0,
      /* xOffset */       0,
      /* xFit */          0,
      /* xRender */       0
   };


/*
** Reduce the length of the line segment by amt (if possible) by
** modifying the location of *t.
*/
static void pik_chop(Pik *p, PPoint *f, PPoint *t, PNum amt){
  PNum dx = t->x - f->x;
  PNum dy = t->y - f->y;
  PNum dist = sqrt(dx*dx + dy*dy);
  PNum r;
  if( dist<=amt ){
    *t = *f;
    return;
  }
  r = 1.0 - amt/dist;
  t->x = f->x + r*dx;
  t->y = f->y + r*dy;
}

/*
** Draw an arrowhead on the end of the line segment from pFrom to pTo.
** Also, shorten the line segment (by changing the value of pTo) so that
** the shaft of the arrow does not extend into the arrowhead.
*/
static void pik_draw_arrowhead(Pik *p, PPoint *f, PPoint *t, PElem *pElem){
  PNum dx = t->x - f->x;
  PNum dy = t->y - f->y;
  PNum dist = sqrt(dx*dx + dy*dy);
  PNum h = p->hArrow * pElem->sw;
  PNum w = p->wArrow * pElem->sw;
  PNum e1, ddx, ddy;
  PNum bx, by;
  if( pElem->color<0.0 ) return;
  if( pElem->sw<=0.0 ) return;
  if( dist<=0.0 ) return;  /* Unable */
  dx /= dist;
  dy /= dist;
  e1 = dist - h;
  if( e1<0.0 ){
    e1 = 0.0;
    h = dist;
  }
  ddx = -w*dy;
  ddy = w*dx;
  bx = f->x + e1*dx;
  by = f->y + e1*dy;
  pik_append_xy(p,"<polygon points=\"", t->x, t->y);
  pik_append_xy(p," ",bx-ddx, by-ddy);
  pik_append_xy(p," ",bx+ddx, by+ddy);
  pik_append_clr(p,"\" style=\"fill:",pElem->color,"\"/>\n");
  pik_chop(p,f,t,h/2);
}

/*
** Compute the relative offset to an edge location from the reference for a
** an element.
*/
static PPoint pik_elem_offset(Pik *p, PElem *pElem, int cp){
  if( pElem->type->xOffset==0 ){
    return boxOffset(p, pElem, cp);
  }else{
    return pElem->type->xOffset(p, pElem, cp);
  }
}


/*
** Append raw text to zOut
*/
static void pik_append(Pik *p, const char *zText, int n){
  if( n<0 ) n = (int)strlen(zText);
  if( p->nOut+n>=p->nOutAlloc ){
    int nNew = (p->nOut+n)*2 + 1;
    char *z = realloc(p->zOut, nNew);
    if( z==0 ){
      pik_error(p, 0, 0);
      return;
    }
    p->zOut = z;
    p->nOutAlloc = n;
  }
  memcpy(p->zOut+p->nOut, zText, n);
  p->nOut += n;
  p->zOut[p->nOut] = 0;
}

/*
** Append text to zOut with HTML characters escaped.
**
**   *  The space character is changed into "&nbsp;" if mFlags as the
**      0x01 bit set.  This is needed when outputting text to preserve
**      leading and trailing whitespace.
**
**   *  The "&" character is changed into "&amp;" if mFlags as the
**      0x02 bit set.  This is needed when generating error message text.
**
**   *  Except for the above, only "<" and ">" are escaped.
*/
static void pik_append_text(Pik *p, const char *zText, int n, int mFlags){
  int i;
  char c;
  int bQSpace = mFlags & 1;
  int bQAmp = mFlags & 2;
  if( n<0 ) n = (int)strlen(zText);
  while( n>0 ){
    for(i=0; i<n; i++){
      c = zText[i];
      if( c=='<' || c=='>' ) break;
      if( c==' ' && bQSpace ) break;
      if( c=='&' && bQAmp ) break;
    }
    if( i ) pik_append(p, zText, i);
    if( i==n ) break;
    switch( c ){
      case '<': {  pik_append(p, "&lt;", 4);  break;  }
      case '>': {  pik_append(p, "&gt;", 4);  break;  }
      case '&': {  pik_append(p, "&amp;", 5);  break;  }
      case ' ': {  pik_append(p, "&nbsp;", 6);  break;  }
    }
    i++;
    n -= i;
    zText += i;
    i = 0;
  }
}

/* Append a PNum value
*/
static void pik_append_num(Pik *p, const char *z,PNum v){
  char buf[100];
  snprintf(buf, sizeof(buf)-1, "%.10g", (double)v);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, z, -1);
  pik_append(p, buf, -1);
}

/* Append a PPoint value  (Used for debugging only)
*/
static void pik_append_point(Pik *p, const char *z, PPoint *pPt){
  char buf[100];
  snprintf(buf, sizeof(buf)-1, "%.10g,%.10g", 
          (double)pPt->x, (double)pPt->y);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, z, -1);
  pik_append(p, buf, -1);
}

/* Append a PNum value surrounded by text.  Do coordinate transformations
** on the value.
*/
static void pik_append_x(Pik *p, const char *z1, PNum v, const char *z2){
  char buf[200];
  v -= p->bbox.sw.x;
  snprintf(buf, sizeof(buf)-1, "%s%d%s", z1, (int)(p->rScale*v), z2);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}
static void pik_append_y(Pik *p, const char *z1, PNum v, const char *z2){
  char buf[200];
  v = p->bbox.ne.y - v;
  snprintf(buf, sizeof(buf)-1, "%s%d%s", z1, (int)(p->rScale*v), z2);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}
static void pik_append_xy(Pik *p, const char *z1, PNum x, PNum y){
  char buf[200];
  x = x - p->bbox.sw.x;
  y = p->bbox.ne.y - y;
  snprintf(buf, sizeof(buf)-1, "%s%d,%d", z1,
       (int)(p->rScale*x), (int)(p->rScale*y));
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}
static void pik_append_dis(Pik *p, const char *z1, PNum v, const char *z2){
  char buf[200];
  snprintf(buf, sizeof(buf)-1, "%s%d%s", z1, (int)(p->rScale*v), z2);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}
static void pik_append_clr(Pik *p, const char *z1, PNum v, const char *z2){
  char buf[200];
  int x = (int)v;
  int r = (x>>16) & 0xff;
  int g = (x>>8) & 0xff;
  int b = x & 0xff;
  snprintf(buf, sizeof(buf)-1, "%srgb(%d,%d,%d)%s", z1, r, g, b, z2);
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}

/* Append an SVG path A record:
**
**    A r1 r2 0 0 0 x y
*/
static void pik_append_arc(Pik *p, PNum r1, PNum r2, PNum x, PNum y){
  char buf[200];
  x = x - p->bbox.sw.x;
  y = p->bbox.ne.y - y;
  snprintf(buf, sizeof(buf)-1, "A%d %d 0 0 0 %d %d", 
     (int)(p->rScale*r1), (int)(p->rScale*r2),
     (int)(p->rScale*x), (int)(p->rScale*y));
  buf[sizeof(buf)-1] = 0;
  pik_append(p, buf, -1);
}

/* Append a style="..." text.  But, leave the quote unterminated, in case
** the caller wants to add some more.
*/
static void pik_append_style(Pik *p, PElem *pElem){
  pik_append(p, "style=\"", -1);
  if( pElem->fill>=0 ){
    pik_append_clr(p, "fill:", pElem->fill, ";");
  }else{
    pik_append(p,"fill:none;",-1);
  }
  if( pElem->sw>0.0 && pElem->color>=0.0 ){
    PNum sw = pElem->sw;
    if( sw*p->rScale<1.0 ) sw = 1.1/p->rScale;
    pik_append_dis(p, "stroke-width:", sw, ";");
    pik_append_clr(p, "stroke:",pElem->color,";");
    if( pElem->dotted>0.0 ){
      PNum v = pElem->dotted;
      if( sw<2.1/p->rScale ) sw = 2.1/p->rScale;
      pik_append_dis(p,"stroke-dasharray:",sw,"");
      pik_append_dis(p,",",v,";");
    }else if( pElem->dashed>0.0 ){
      PNum v = pElem->dashed;
      pik_append_dis(p,"stroke-dasharray:",v,"");
      pik_append_dis(p,",",v,";");
    }
  }
}

/*
** Compute the vertical locations for all text items in the
** element pElem.  In other words, set every pElem->aTxt[*].eCode
** value to contain exactly one of: TP_ABOVE2, TP_ABOVE, TP_CENTER,
** TP_BELOW, or TP_BELOW2 is set.
*/
static void pik_txt_vertical_layout(Pik *p, PElem *pElem){
  int n, i;
  PToken *aTxt;
  n = pElem->nTxt;
  if( n==0 ) return;
  aTxt = pElem->aTxt;
  if( n==1 ){
    if( (aTxt[0].eCode & TP_VMASK)==0 ){
      aTxt[0].eCode |= TP_CENTER;
    }
  }else{
    int allSlots = 0;
    int aFree[5];
    int iSlot;
    int j;
    /* If there is more than one TP_ABOVE, change the first to TP_ABOVE2. */
    for(j=0, i=n-1; i>=0; i--){
      if( aTxt[i].eCode & TP_ABOVE ){
        if( j==0 ){
          j++;
        }else{
          aTxt[i].eCode = (aTxt[i].eCode & ~TP_VMASK) | TP_ABOVE2;
          break;
        }
      }
    }
    /* If more than one TP_BELOW, change the last to TP_BELOW2 */
    for(j=0, i=0; i<n; i++){
      if( aTxt[i].eCode & TP_BELOW ){
        if( j==0 ){
          j++;
        }else{
          aTxt[i].eCode = (aTxt[i].eCode & ~TP_VMASK) | TP_BELOW2;
          break;
        }
      }
    }
    /* Compute a mask of all slots used */
    for(i=0; i<n; i++) allSlots |= aTxt[i].eCode & TP_VMASK;
    /* Set of an array of available slots */
    iSlot = 0;
    if( n>=4 && (allSlots & TP_ABOVE2)==0 ) aFree[iSlot++] = TP_ABOVE2;
    if( (allSlots & TP_ABOVE)==0 ) aFree[iSlot++] = TP_ABOVE;
    if( (n&1)!=0 ) aFree[iSlot++] = TP_CENTER;
    if( (allSlots & TP_BELOW)==0 ) aFree[iSlot++] = TP_BELOW;
    if( n>=4 && (allSlots & TP_BELOW2)==0 ) aFree[iSlot++] = TP_BELOW2;
    /* Set the VMASK for all unassigned texts */
    for(i=iSlot=0; i<n; i++){
      if( (aTxt[i].eCode & TP_VMASK)==0 ){
        aTxt[i].eCode |= aFree[iSlot++];
      }
    }
  }
}

/* Append multiple <text> SGV element for the text fields of the PElem
*/
static void pik_append_txt(Pik *p, PElem *pElem){
  PNum dy;      /* Half the height of a single line of text */
  PNum dy2;     /* Extra vertical space around the center */
  int n, i, nz;
  PNum x, y, orig_y;
  const char *z;
  PToken *aTxt;
  int hasCenter = 0;

  if( p->nErr ) return;
  if( pElem->nTxt==0 ) return;
  aTxt = pElem->aTxt;
  dy = 0.5*p->charHeight;
  n = pElem->nTxt;
  pik_txt_vertical_layout(p, pElem);
  x = pElem->ptAt.x;
  for(i=0; i<n; i++){
    if( (pElem->aTxt[i].eCode & TP_CENTER)!=0 ) hasCenter = 1;
  }
  if( hasCenter ){
    dy2 = dy;
  }else if( pElem->type->isLine ){
    dy2 = pElem->sw;
  }else{
    dy2 = 0.0;
  }
  for(i=0; i<n; i++){
    PToken *t = &aTxt[i];
    orig_y = y = pElem->ptAt.y;
    if( t->eCode & TP_ABOVE2 ) y += dy2 + 3*dy;
    if( t->eCode & TP_ABOVE  ) y += dy2 + dy;
    if( t->eCode & TP_BELOW  ) y -= dy2 + dy;
    if( t->eCode & TP_BELOW2 ) y -= dy2 + 3*dy;

    pik_append_x(p, "<text x=\"", x, "\"");
    pik_append_y(p, " y=\"", y, "\"");
    if( t->eCode & TP_RJUST ){
      pik_append(p, " text-anchor=\"end\"", -1);
    }else if( t->eCode & TP_LJUST ){
      pik_append(p, " text-anchor=\"start\"", -1);
    }else{
      pik_append(p, " text-anchor=\"middle\"", -1);
    }
    if( t->eCode & TP_ITALIC ){
      pik_append(p, " font-style=\"italic\"", -1);
    }
    if( t->eCode & TP_BOLD ){
      pik_append(p, " font-weight=\"bold\"", -1);
    }
    if( pElem->color>=0.0 ){
      pik_append_clr(p, " fill=\"", pElem->color, "\"");
    }
    if( p->fontScale<=0.99 || p->fontScale>=1.01 ){
      pik_append_num(p, " font-size=\"", p->fontScale*100.0);
      pik_append(p, "%\"", 2);
    }
    if( (t->eCode & TP_ALIGN)!=0 && pElem->nPath>=2 ){
      int n = pElem->nPath;
      PNum dx = pElem->aPath[n-1].x - pElem->aPath[0].x;
      PNum dy = pElem->aPath[n-1].y - pElem->aPath[0].y;
      PNum ang = atan2(dy,dx)*-180/M_PI;
      pik_append_num(p, " transform=\"rotate(", ang);
      pik_append_xy(p, " ", x, orig_y);
      pik_append(p,")\"",2);
    }
    pik_append(p," dominant-baseline=\"central\">",-1);
    z = t->z+1;
    nz = t->n-2;
    while( nz>0 ){
      int j;
      for(j=0; j<nz && z[j]!='\\'; j++){}
      if( j ) pik_append_text(p, z, j, 1);
      nz -= j+1;
      z += j+1;
    }
    pik_append(p, "</text>\n", -1);
  }
}


/*
** Generate an error message for the output.  pErr is the token at which
** the error should point.  zMsg is the text of the error message. If
** either pErr or zMsg is NULL, generate an out-of-memory error message.
**
** This routine is a no-op if there has already been an error reported.
*/
static void pik_error(Pik *p, PToken *pErr, const char *zMsg){
  int i, j;
  int iCol;
  int nExtra;
  char c;
  if( p==0 ) return;
  if( p->nErr ) return;
  p->nErr++;
  if( zMsg==0 ){
    pik_append(p, "\n<div><p>Out of memory</p></div>\n", -1);
    return;
  }
  if( pErr==0 ){
    pik_append(p, "\n", 1);
    pik_append_text(p, zMsg, -1, 0);
    return;
  }
  i = (int)(pErr->z - p->zIn);
  for(j=i; j>0 && p->zIn[j-1]!='\n'; j--){}
  iCol = i - j;
  for(nExtra=0; (c = p->zIn[i+nExtra])!=0 && c!='\n'; nExtra++){}
  pik_append(p, "<div><pre>\n", -1);
  pik_append_text(p, p->zIn, i+nExtra, 3);
  pik_append(p, "\n", 1);
  for(i=0; i<iCol; i++){ pik_append(p, " ", 1); }
  for(i=0; i<pErr->n; i++) pik_append(p, "^", 1);
  pik_append(p, "\nERROR: ", -1);
  pik_append_text(p, zMsg, -1, 0);
  pik_append(p, "\n", 1);
  pik_append(p, "\n</pre></div>\n", -1);
}

/* Free a complete list of elements */
static void pik_elist_free(Pik *p, PEList *pEList){
  int i;
  if( pEList==0 ) return;
  for(i=0; i<pEList->n; i++){
    pik_elem_free(p, pEList->a[i]);
  }
  free(pEList->a);
  free(pEList);
  return;
}

/* Free a single element, and its substructure */
static void pik_elem_free(Pik *p, PElem *pElem){
  if( pElem==0 ) return;
  free(pElem->zName);
  pik_elist_free(p, pElem->pSublist);
  free(pElem->aPath);
  free(pElem);
}

/* Convert a numeric literal into a number.  Return that number.
** There is no error handling because the tokenizer has already
** assured us that the numeric literal is valid.
**
** Allowed number forms:
**
**   (1)    Floating point literal
**   (2)    Same as (1) but followed by a unit: "cm", "mm", "in",
**          "px", "pt", or "pc".
**   (3)    Hex integers: 0x000000
**
** This routine returns the result in inches.  If a different unit
** is specified, the conversion happens automatically.
*/
PNum pik_atof(Pik *p, PToken *num){
  char *endptr;
  PNum ans;
  if( num->n>=3 && num->z[0]=='0' && (num->z[1]=='x'||num->z[1]=='X') ){
    return (PNum)strtol(num->z+2, 0, 16);
  }
  ans = strtod(num->z, &endptr);
  if( (int)(endptr - num->z)==num->n-2 ){
    char c1 = endptr[0];
    char c2 = endptr[1];
    if( c1=='c' && c2=='m' ){
      ans /= 2.54;
    }else if( c1=='m' && c2=='m' ){
      ans /= 25.4;
    }else if( c1=='p' && c2=='x' ){
      ans /= 96;
    }else if( c1=='p' && c2=='t' ){
      ans /= 72;
    }else if( c1=='p' && c2=='c' ){
      ans /= 6;
    }
  }
  return ans;
}

/* Return true if a bounding box is empty.
*/
static int pik_bbox_isempty(PBox *p){
  return p->sw.x>p->ne.x;
}

/* Initialize a bounding box to an empty container
*/
static void pik_bbox_init(PBox *p){
  p->sw.x = 1.0;
  p->sw.y = 1.0;
  p->ne.x = 0.0;
  p->ne.y = 0.0;
}

/* Enlarge the PBox of the first argument so that it fully
** covers the second PBox
*/
static void pik_bbox_addbox(PBox *pA, PBox *pB){
  if( pik_bbox_isempty(pA) ){
    *pA = *pB;
  }
  if( pik_bbox_isempty(pB) ) return;
  if( pA->sw.x>pB->sw.x ) pA->sw.x = pB->sw.x;
  if( pA->sw.y>pB->sw.y ) pA->sw.y = pB->sw.y;
  if( pA->ne.x<pB->ne.x ) pA->ne.x = pB->ne.x;
  if( pA->ne.y<pB->ne.y ) pA->ne.y = pB->ne.y;
}

/* Enlarge the PBox of the first argument, if necessary, so that
** it contains the PPoint in the second argument
*/
static void pik_bbox_addpt(PBox *pA, PPoint *pPt){
  if( pik_bbox_isempty(pA) ){
    pA->ne = *pPt;
    pA->sw = *pPt;
    return;
  }
  if( pA->sw.x>pPt->x ) pA->sw.x = pPt->x;
  if( pA->sw.y>pPt->y ) pA->sw.y = pPt->y;
  if( pA->ne.x<pPt->x ) pA->ne.x = pPt->x;
  if( pA->ne.y<pPt->y ) pA->ne.y = pPt->y;
}

/* Enlarge the PBox so that it is able to contain an ellipse
** centered at x,y and with radiuses rx and ry.
*/
static void pik_bbox_addellipse(PBox *pA, PNum x, PNum y, PNum rx, PNum ry){
  if( pik_bbox_isempty(pA) ){
    pA->ne.x = x+rx;
    pA->ne.y = y+ry;
    pA->sw.x = x-rx;
    pA->sw.y = y-ry;
    return;
  }
  if( pA->sw.x>x-rx ) pA->sw.x = x-rx;
  if( pA->sw.y>y-ry ) pA->sw.y = y-ry;
  if( pA->ne.x<x+rx ) pA->ne.x = x+rx;
  if( pA->ne.y<y+ry ) pA->ne.y = y+ry;
}



/* Append a new element onto the end of an element_list.  The
** element_list is created if it does not already exist.  Return
** the new element list.
*/
static PEList *pik_elist_append(Pik *p, PEList *pEList, PElem *pElem){
  if( pElem==0 ) return pEList;
  if( pEList==0 ){
    pEList = malloc(sizeof(*pEList));
    if( pEList==0 ){
      pik_error(p, 0, 0);
      pik_elem_free(p, pElem);
      return 0;
    }
    memset(pEList, 0, sizeof(*pEList));
  }
  if( pEList->n>=pEList->nAlloc ){
    int nNew = (pEList->n+5)*2;
    PElem **pNew = realloc(pEList->a, sizeof(PElem*)*nNew);
    if( pNew==0 ){
      pik_error(p, 0, 0);
      pik_elem_free(p, pElem);
      return pEList;
    }
    pEList->nAlloc = nNew;
    pEList->a = pNew;
  }
  pEList->a[pEList->n++] = pElem;
  p->list = pEList;
  return pEList;
}

/* Convert an element class name into a PClass pointer
*/
static const PClass *pik_find_class(PToken *pId){
  int first = 0;
  int last = count(aClass) - 1;
  do{
    int mid = (first+last)/2;
    int c = strncmp(aClass[mid].zName, pId->z, pId->n);
    if( c==0 ){
      c = aClass[mid].zName[pId->n]!=0;
      if( c==0 ) return &aClass[mid];
    }
    if( c<0 ){
      first = mid + 1;
    }else{
      last = mid - 1;
    }
  }while( first<=last );
  return 0;
}

/* Allocate and return a new PElem object.
**
** If pId!=0 then pId is an identifier that defines the element class.
** If pStr!=0 then it is a STRING literal that defines a text object.
** If pSublist!=0 then this is a [...] object. If all three parameters
** are NULL then this is a no-op object used to define a PLACENAME.
*/
static PElem *pik_elem_new(Pik *p, PToken *pId, PToken *pStr,PEList *pSublist){
  PElem *pNew;
  int miss = 0;

  if( p->nErr ) return 0;
  pNew = malloc( sizeof(*pNew) );
  if( pNew==0 ){
    pik_error(p,0,0);
    pik_elist_free(p, pSublist);
    return 0;
  }
  memset(pNew, 0, sizeof(*pNew));
  p->cur = pNew;
  p->nTPath = 1;
  p->thenFlag = 0;
  if( p->list==0 || p->list->n==0 ){
    pNew->ptAt.x = pNew->ptAt.y = 0.0;
  }else{
    PElem *pPrior = p->list->a[p->list->n-1];
    pNew->ptAt = pPrior->ptExit;
    switch( p->eDir ){
      default:         pNew->eWith = CP_W;   break;
      case DIR_LEFT:   pNew->eWith = CP_E;   break;
      case DIR_UP:     pNew->eWith = CP_S;   break;
      case DIR_DOWN:   pNew->eWith = CP_N;   break;
    }
  }
  p->aTPath[0] = pNew->ptAt;
  pNew->with = pNew->ptAt;
  pNew->outDir = pNew->inDir = p->eDir;
  pNew->iLayer = (int)pik_value(p, "layer", 5, &miss);
  if( miss ) pNew->iLayer = 1000;
  if( pNew->iLayer<0 ) pNew->iLayer = 0;
  if( pSublist ){
    pNew->type = &sublistClass;
    pNew->pSublist = pSublist;
    sublistClass.xInit(p,pNew);
    return pNew;
  }
  if( pStr ){
    PToken n;
    n.z = "text";
    n.n = 4;
    pNew->type = pik_find_class(&n);
    assert( pNew->type!=0 );
    pNew->errTok = *pStr;
    pNew->type->xInit(p, pNew);
    pik_add_txt(p, pStr, pStr->eCode);
    return pNew;
  }
  if( pId ){
    pNew->errTok = *pId;
    const PClass *pClass = pik_find_class(pId);
    if( pClass ){
      pNew->type = pClass;
      pNew->sw = pik_value(p, "thickness",9,0);
      pNew->fill = pik_value(p, "fill",4,0);
      pNew->color = pik_value(p, "color",5,0);
      pClass->xInit(p, pNew);
      return pNew;
    }
    pik_error(p, pId, "unknown element type");
    pik_elem_free(p, pNew);
    return 0;
  }
  pNew->type = &noopClass;
  pNew->ptExit = pNew->ptEnter = pNew->ptAt;
  return pNew;
}

/*
** Set the output direction and exit point for an element.
*/
static void pik_elem_set_exit(Pik *p, PElem *pElem, int eDir){
  assert( ValidDir(eDir) );
  pElem->outDir = eDir;
  if( !pElem->type->isLine || pElem->bClose ){
    pElem->ptExit = pElem->ptAt;
    switch( pElem->outDir ){
      default:         pElem->ptExit.x += pElem->w*0.5;  break;
      case DIR_LEFT:   pElem->ptExit.x -= pElem->w*0.5;  break;
      case DIR_UP:     pElem->ptExit.y += pElem->h*0.5;  break;
      case DIR_DOWN:   pElem->ptExit.y -= pElem->h*0.5;  break;
    }
  }
}

/* Change the direction of travel
*/
static void pik_set_direction(Pik *p, int eDir){
  assert( ValidDir(eDir) );
  p->eDir = eDir;
  if( p->list && p->list->n ){
    pik_elem_set_exit(p, p->list->a[p->list->n-1], eDir);
  }
}

/* Move all coordinates contained within an element (and within its
** substructure) by dx, dy
*/
static void pik_elem_move(PElem *pElem, PNum dx, PNum dy){
  int i;
  pElem->ptAt.x += dx;
  pElem->ptAt.y += dy;
  pElem->ptEnter.x += dx;
  pElem->ptEnter.y += dy;
  pElem->ptExit.x += dx;
  pElem->ptExit.y += dy;
  pElem->bbox.ne.x += dx;
  pElem->bbox.ne.y += dy;
  pElem->bbox.sw.x += dx;
  pElem->bbox.sw.y += dy;
  for(i=0; i<pElem->nPath; i++){
    pElem->aPath[i].x += dx;
    pElem->aPath[i].y += dy;
  }
  if( pElem->pSublist ){
    pik_elist_move(pElem->pSublist, dx, dy);
  }
}
static void pik_elist_move(PEList *pList, PNum dx, PNum dy){
  int i;
  for(i=0; i<pList->n; i++){
    pik_elem_move(pList->a[i], dx, dy);
  }
}

/*
** Check to see if it is ok to set the value of paraemeter mThis.
** Return 0 if it is ok. If it not ok, generate an appropriate
** error message and return non-zero.
**
** Flags are set in pElem so that the same element or conflicting
** elements may not be set again.
**
** To be ok, bit mThis must be clear and no more than one of
** the bits identified by mBlockers may be set.
*/
static int pik_param_ok(
  Pik *p,             /* For storing the error message (if any) */
  PElem *pElem,       /* The element under construction */
  PToken *pId,        /* Make the error point to this token */
  int mThis,          /* Value we are trying to set */
  int mBlockers       /* Other value that might block this one */
){
  int m;
  if( pElem->mProp & mThis ){
    pik_error(p, pId, "value is already set");
    return 1;
  }
  if( pElem->mCalc & mThis ){
    pik_error(p, pId, "value already fixed by prior constraints");
    return 1;
  }
  m = pElem->mProp & mBlockers;
  if( m ){
    pElem->mCalc |= mThis|mBlockers;
  }
  pElem->mProp |= mThis;
  return 0;
}


/*
** Set a numeric property like "width 7" or "radius 200%".
**
** The rAbs term is an absolute value to add in.  rRel is
** a relative value by which to change the current value.
*/
void pik_set_numprop(Pik *p, PToken *pId, PNum rAbs, PNum rRel){
  PElem *pElem = p->cur;
  switch( pId->eType ){
    case T_HEIGHT:
      if( pik_param_ok(p, pElem, pId, A_HEIGHT, A_BOTTOM|A_TOP|A_AT) ) return;
      pElem->h = pElem->h*rRel + rAbs;
      break;
    case T_TOP:
      if( pik_param_ok(p, pElem, pId, A_TOP, A_BOTTOM|A_WIDTH|A_AT) ) return;
      pElem->top = rAbs;
      break;
    case T_BOTTOM:
      if( pik_param_ok(p, pElem, pId, A_BOTTOM, A_TOP|A_WIDTH|A_AT) ) return;
      pElem->bottom = rAbs;
      break;
    case T_WIDTH:
      if( pik_param_ok(p, pElem, pId, A_WIDTH, A_RIGHT|A_LEFT|A_AT) ) return;
      pElem->w = pElem->w*rRel + rAbs;
      break;
    case T_RIGHT:
      if( pik_param_ok(p, pElem, pId, A_RIGHT, A_WIDTH|A_LEFT|A_AT) ) return;
      pElem->right = rAbs;
      break;
    case T_LEFT:
      if( pik_param_ok(p, pElem, pId, A_LEFT, A_WIDTH|A_RIGHT|A_AT) ) return;
      pElem->left = rAbs;
      break;
    case T_RADIUS:
      if( pik_param_ok(p, pElem, pId, A_RADIUS, 0) ) return;
      pElem->rad = pElem->rad*rRel + rAbs;
      break;
    case T_DIAMETER:
      if( pik_param_ok(p, pElem, pId, A_RADIUS, 0) ) return;
      pElem->rad = pElem->rad*rRel + 0.5*rAbs; /* diam it 2x radius */
      break;
    case T_THICKNESS:
      if( pik_param_ok(p, pElem, pId, A_THICKNESS, 0) ) return;
      pElem->sw = pElem->sw*rRel + rAbs;
      break;
    case T_FILL:
      if( pik_param_ok(p, pElem, pId, A_FILL, 0) ) return;
      pElem->fill = rAbs;
      break;
    case T_COLOR:
      if( pik_param_ok(p, pElem, pId, A_COLOR, 0) ) return;
      pElem->color = rAbs;
      break;
  }
  if( pElem->type->xNumProp ){
    pElem->type->xNumProp(p, pElem, pId);
  }
  return;
}

/*
** Set a "dashed" property like "dash 0.05" or "chop"
**
** Use the value supplied by pVal if available.  If pVal==0, use
** a default.
*/
void pik_set_dashed(Pik *p, PToken *pId, PNum *pVal){
  PElem *pElem = p->cur;
  PNum v;
  switch( pId->eType ){
    case T_DOTTED:  {
      v = pVal==0 ? pik_value(p,"dashwid",7,0) : *pVal;
      pElem->dotted = v;
      pElem->dashed = 0.0;
      break;
    }
    case T_DASHED:  {
      v = pVal==0 ? pik_value(p,"dashwid",7,0) : *pVal;
      pElem->dashed = v;
      pElem->dotted = 0.0;
      break;
    }
  }
}


/* Add a new term to the path for a line-oriented object by transferring
** the information in the ptTo field over onto the path and into ptFrom
** resetting the ptTo.
*/
static void pik_then(Pik *p, PToken *pToken, PElem *pElem){
  int n;
  if( !pElem->type->isLine ){
    pik_error(p, pToken, "use with line-oriented elements only");
    return;
  }
  n = p->nTPath - 1;
  if( n<1 ){
    pik_error(p, pToken, "no prior path points");
    return;
  }
  p->thenFlag = 1;
}

/* Advance to the next entry in p->aTPath.  Return its index.
*/
static int pik_next_rpath(Pik *p, PToken *pErr){
  int n = p->nTPath - 1;
  if( n+1>=count(p->aTPath) ){
    pik_error(0, pErr, "too many path elements");
    return n;
  }
  n++;
  p->nTPath++;
  p->aTPath[n] = p->aTPath[n-1];
  p->mTPath = 0;
  return n;
}

/* Add a direction term to an element.  "up 0.5", or "left 3", or "down"
** or "down to 1.3".  Specific processing depends on parameters:
**
**   pVal==0   Add the default width or height to the coordinate.
**             Used to implement "down" and similar.
**
**   rel==0    Add or subtract *pVal to the path coordinate.  Used to
**             implement "up 0.5" and similar.
**
**   rel==1    Multiple 0.01*pVal with the width or height (as appropriate)
**             and add that to the coordinate.  Used for "left 50%" and
**             similar.
**
**   rel==2    Make the coordinate exactly equal to *pVal.  Used to
**             implement things like "down to 1.3".
*/
static void pik_add_direction(Pik *p, PToken *pDir, PNum *pVal, int rel){
  PElem *pElem = p->cur;
  int n;
  int dir;
  PNum scale = 1.0;
  if( !pElem->type->isLine ){
    if( pDir ){
      pik_error(p, pDir, "use with line-oriented elements only");
    }else{
      PToken x = pik_next_semantic_token(p, &pElem->errTok);
      pik_error(p, &x, "syntax error");
    }
    return;
  }
  if( pVal && rel==1 ){
    scale = *pVal/100;
    pVal = 0;
  }
  if( rel==2 ){
    pElem->mProp |= A_FROM;
  }
  n = p->nTPath - 1;
  if( p->thenFlag || p->mTPath==3 || n==0 ){
    n = pik_next_rpath(p, pDir);
    p->thenFlag = 0;
  }
  dir = pDir ? pDir->eCode : p->eDir;
  switch( dir ){
    case DIR_UP:
       if( p->mTPath & 2 ) n = pik_next_rpath(p, pDir);
       if( rel==2 ) p->aTPath[n].y = 0;
       p->aTPath[n].y += (pVal ? *pVal : pElem->h*scale);
       p->mTPath |= 2;
       break;
    case DIR_DOWN:
       if( p->mTPath & 2 ) n = pik_next_rpath(p, pDir);
       if( rel==2 ) p->aTPath[n].y = 0;
       p->aTPath[n].y -= (pVal ? *pVal : pElem->h*scale);
       p->mTPath |= 2;
       break;
    case DIR_RIGHT:
       if( p->mTPath & 1 ) n = pik_next_rpath(p, pDir);
       if( rel==2 ) p->aTPath[n].x = 0;
       p->aTPath[n].x += (pVal ? *pVal : pElem->w*scale);
       p->mTPath |= 1;
       break;
    case DIR_LEFT:
       if( p->mTPath & 1 ) n = pik_next_rpath(p, pDir);
       if( rel==2 ) p->aTPath[n].x = 0;
       p->aTPath[n].x -= (pVal ? *pVal : pElem->w*scale);
       p->mTPath |= 1;
       break;
  }
  pElem->outDir = dir;
}

/* Process a movement attribute of the form "right until even with ..."
**
** pDir is the first keyword, "right" or "left" or "up" or "down".
** The movement is in that direction until its closest approach to
** point specified by pPoint.
*/
static void pik_evenwith(Pik *p, PToken *pDir, PPoint *pPlace){
  PElem *pElem = p->cur;
  int n;
  if( !pElem->type->isLine ){
    pik_error(p, pDir, "use with line-oriented elements only");
    return;
  }
  n = p->nTPath - 1;
  if( p->thenFlag || p->mTPath==3 || n==0 ){
    n = pik_next_rpath(p, pDir);
    p->thenFlag = 0;
  }
  switch( pDir->eCode ){
    case DIR_DOWN:
    case DIR_UP:
       if( p->mTPath & 2 ) n = pik_next_rpath(p, pDir);
       p->aTPath[n].y = pPlace->y;
       p->mTPath |= 2;
       break;
    case DIR_RIGHT:
    case DIR_LEFT:
       if( p->mTPath & 1 ) n = pik_next_rpath(p, pDir);
       p->aTPath[n].x = pPlace->x;
       p->mTPath |= 1;
       break;
  }
  pElem->outDir = pDir->eCode;
}

/* Set the "from" of an element
*/
static void pik_set_from(Pik *p, PElem *pElem, PToken *pTk, PPoint *pPt){
  if( !pElem->type->isLine ){
    pik_error(p, pTk, "use \"at\" to position this object");
    return;
  }
  if( pElem->mProp & A_FROM ){
    pik_error(p, pTk, "line start location already fixed");
    return;
  }
  if( pElem->bClose ){
    pik_error(p, pTk, "polygon is closed");
    return;
  }
  if( p->nTPath>1 ){
    PNum dx = pPt->x - p->aTPath[0].x;
    PNum dy = pPt->y - p->aTPath[0].y;
    int i;
    for(i=1; i<p->nTPath; i++){
      p->aTPath[i].x += dx;
      p->aTPath[i].y += dy;
    }
  }
  p->aTPath[0] = *pPt;
  p->mTPath = 3;
  pElem->mProp |= A_FROM;
}

/* Set the "to" of an element
*/
static void pik_add_to(Pik *p, PElem *pElem, PToken *pTk, PPoint *pPt){
  int n = p->nTPath-1;
  if( !pElem->type->isLine ){
    pik_error(p, pTk, "use \"at\" to position this object");
    return;
  }
  if( pElem->bClose ){
    pik_error(p, pTk, "polygon is closed");
    return;
  }
  if( p->mTPath || p->mTPath ){
    n = pik_next_rpath(p, pTk);
  }
  p->aTPath[n] = *pPt;
  p->mTPath = 3;
}

static void pik_close_path(Pik *p, PToken *pErr){
  PElem *pElem = p->cur;
  if( p->nTPath<3 ){
    pik_error(p, pErr,
      "need at least 3 vertexes in order to close the polygon");
    return;
  }
  if( pElem->bClose ){
    pik_error(p, pErr, "polygon already closed");
    return;
  }
  pElem->bClose = 1;
}


/* Set the "at" of an element
*/
static void pik_set_at(Pik *p, PToken *pEdge, PPoint *pAt, PToken *pErrTok){
  PElem *pElem;
  if( p->nErr ) return;
  pElem = p->cur;

  if( pElem->type->isLine ){
    pik_error(p, pErrTok, "use \"from\" and \"to\" to position this object");
    return;
  }
  if( pElem->mProp & A_AT ){
    pik_error(p, pErrTok, "location fixed by prior \"at\"");
    return;
  }
  if( pElem->mCalc & A_AT ){
    pik_error(p, pErrTok, "location fixed by prior constraints");
    return;
  }
  if( pElem->mProp & (A_WIDTH|A_LEFT|A_RIGHT) ){
    pElem->mCalc |= (A_WIDTH|A_LEFT|A_RIGHT|A_AT);
  }
  if( pElem->mProp & (A_HEIGHT|A_TOP|A_BOTTOM) ){
    pElem->mCalc |= (A_HEIGHT|A_TOP|A_BOTTOM|A_AT);
  }
  pElem->mProp |= A_AT;
  pElem->eWith = pEdge ? pEdge->eEdge : CP_C;
  pElem->with = *pAt;
}

/*
** Try to add a text attribute to an element
*/
static void pik_add_txt(Pik *p, PToken *pTxt, int iPos){
  PElem *pElem = p->cur;
  PToken *pT;
  if( pElem->nTxt >= count(pElem->aTxt) ){
    pik_error(p, pTxt, "too many text terms");
    return;
  }
  pT = &pElem->aTxt[pElem->nTxt++];
  *pT = *pTxt;
  pT->eCode = iPos;
}

/* Merge "text-position" flags
*/
static int pik_text_position(Pik *p, int iPrev, PToken *pFlag){
  int iRes = iPrev;
  switch( pFlag->eType ){
    case T_CENTER:   /* no-op */                          break;
    case T_LJUST:    iRes = (iRes&~TP_JMASK) | TP_LJUST;  break;
    case T_RJUST:    iRes = (iRes&~TP_JMASK) | TP_RJUST;  break;
    case T_ABOVE:    iRes = (iRes&~TP_VMASK) | TP_ABOVE;  break;
    case T_BELOW:    iRes = (iRes&~TP_VMASK) | TP_BELOW;  break;
    case T_ITALIC:   iRes |= TP_ITALIC;                   break; 
    case T_BOLD:     iRes |= TP_BOLD;                     break; 
    case T_ALIGNED:  iRes |= TP_ALIGN;                    break; 
  }
  return iRes;
}

/* Adjust the width, height, and or radius of the object so that
** it fits around the text that has been added so far.
**
**    (1) Only text specified prior to this attribute is considered.
**    (2) The text size is estimated based on the charht and charwid
**        variable settings.
**    (3) The fitted attributes can be changed again after this
**        attribute, for example using "width 110%" if this auto-fit
**        underestimates the text size.
**    (4) Previously set attributes will not be altered.  In other words,
**        "width 1in fit" might cause the height to change, but the
**        width is now set.
**    (5) This only works for attributes that have an xFit method.
*/
static void pik_size_to_fit(Pik *p, PToken *pFit){
  PElem *pElem;
  int w = 0, h = 0;
  int i;
  if( p->nErr ) return;
  pElem = p->cur;

  if( pElem->nTxt==0 ){
    pik_error(0, pFit, "no text to fit to");
    return;
  }
  if( pElem->type->xFit==0 ) return;
  if( (pElem->mProp & A_HEIGHT)==0 ){
    int hasCenter = 0;
    int hasSingleStack = 0;
    int hasDoubleStack = 0;
    pik_txt_vertical_layout(p, pElem);
    for(i=0; i<pElem->nTxt; i++){
      if( pElem->aTxt[i].eCode & TP_CENTER ){
        hasCenter = 1;
      }else if( pElem->aTxt[i].eCode & (TP_ABOVE2|TP_BELOW2) ){
        hasDoubleStack = 1;
      }else if( pElem->aTxt[i].eCode & (TP_ABOVE|TP_BELOW) ){
        hasSingleStack = 1;
      }
    }
    h = hasCenter + hasSingleStack*2 + hasDoubleStack*2;
  }
  if( (pElem->mProp & A_WIDTH)==0 ){
    for(i=0; i<pElem->nTxt; i++){
      int j, cnt;
      const char *z = pElem->aTxt[i].z;
      int n = pElem->aTxt[i].n;
      /* cnt will be an estimate of the text width.  Do not count
      ** "\" uses as an escape.  Count entities like &lt; as a single
      ** character. */
      for(j=1, cnt=0; j<n-1; j++){
         cnt++;
         if( z[j]=='\\' && z[j+1]!='&' ){
           j++;
         }else if( z[j]=='&' ){
           int k;
           for(k=j+1; k<j+7 && z[k]!=';'; k++){}
           if( z[k]==';' ) j = k;
         }
      }
      if( (pElem->aTxt[i].eCode & TP_JMASK)!=0 ) cnt *= 2;
      if( cnt>w ) w = cnt;
    }
  }
  if( h>0 || w>0 ){
    pik_compute_layout_settings(p);
    pElem->type->xFit(p, pElem, w*p->charWidth, h*p->charHeight);
  }
}

/* Set a local variable name to "val".
**
** The name might be a built-in variable or a color name.  In either case,
** a new application-defined variable is set.  Since app-defined variables
** are searched first, this will override any built-in variables.
*/
static void pik_set_var(Pik *p, PToken *pId, PNum val, PToken *pOp){
  PVar *pVar = p->pVar;
  while( pVar ){
    if( pik_token_eq(pId,pVar->zName)==0 ) break;
    pVar = pVar->pNext;
  }
  if( pVar==0 ){
    char *z;
    pVar = malloc( pId->n+1 + sizeof(*pVar) );
    if( pVar==0 ){
      pik_error(p, 0, 0);
      return;
    }
    pVar->zName = z = (char*)&pVar[1];
    memcpy(z, pId->z, pId->n);
    z[pId->n] = 0;
    pVar->pNext = p->pVar;
    pVar->val = pik_value(p, pId->z, pId->n, 0);
    p->pVar = pVar;
  }
  switch( pOp->eCode ){
    case T_PLUS:  pVar->val += val; break;
    case T_STAR:  pVar->val *= val; break;
    case T_MINUS: pVar->val -= val; break;
    case T_SLASH:
      if( val==0.0 ){
        pik_error(p, pOp, "division by zero");
      }else{
        pVar->val /= val;
      }
      break;
    default:      pVar->val = val; break;
  }
  p->bLayoutVars = 0;  /* Clear the layout setting cache */
}

/*
** Search for the variable named z[0..n-1] in:
**
**   * Application defined variables
**   * Built-in variables
**
** Return the value of the variable if found.  If not found
** return 0.0.  Also if pMiss is not NULL, then set it to 1
** if not found.
**
** This routine is a subroutine to pik_get_var().  But it is also
** used by object implementations to look up (possibly overwritten)
** values for built-in variables like "boxwid".
*/
static PNum pik_value(Pik *p, const char *z, int n, int *pMiss){
  PVar *pVar;
  int first, last, mid, c;
  for(pVar=p->pVar; pVar; pVar=pVar->pNext){
    if( strncmp(pVar->zName,z,n)==0 && pVar->zName[n]==0 ){
      return pVar->val;
    }
  }
  first = 0;
  last = count(aBuiltin)-1;
  while( first<=last ){
    mid = (first+last)/2;
    c = strncmp(z,aBuiltin[mid].zName,n);
    if( c==0 && aBuiltin[mid].zName[n] ) c = 1;
    if( c==0 ) return aBuiltin[mid].val;
    if( c>0 ){
      first = mid+1;
    }else{
      last = mid-1;
    }
  }
  if( pMiss ) *pMiss = 1;
  return 0.0;
}

/*
** Look up a color-name.  Unlike other names in this program, the
** color-names are not case sensitive.  So "DarkBlue" and "darkblue"
** and "DARKBLUE" all find the same value (139).
**
** If not found, return -1.0.  Also post an error if p!=NULL.
**
** Special color names "None" and "Off" return -1.0 without causing
** an error.
*/
static PNum pik_lookup_color(Pik *p, PToken *pId){
  int first, last, mid, c = 0;
  first = 0;
  last = count(aColor)-1;
  while( first<=last ){
    const char *zClr;
    int c1, c2, i;
    mid = (first+last)/2;
    zClr = aColor[mid].zName;
    for(i=0; i<pId->n; i++){
      c1 = zClr[i]&0x7f;
      if( isupper(c1) ) c1 = tolower(c1);
      c2 = pId->z[i]&0x7f;
      if( isupper(c2) ) c2 = tolower(c2);
      c = c2 - c1;
      if( c ) break;
    }
    if( c==0 && aColor[mid].zName[pId->n] ) c = -1;
    if( c==0 ) return (double)aColor[mid].val;
    if( c>0 ){
      first = mid+1;
    }else{
      last = mid-1;
    }
  }
  if( p ) pik_error(p, pId, "not a known color name");
  return -1.0;
}

/* Get the value of a variable.
**
** Search in order:
**
**    *  Application defined variables
**    *  Built-in variables
**    *  Color names
**
** If no such variable is found, throw an error.
*/
static PNum pik_get_var(Pik *p, PToken *pId){
  int miss = 0;
  PNum v = pik_value(p, pId->z, pId->n, &miss);
  if( miss==0 ) return v;
  v = pik_lookup_color(0, pId);
  if( v>=0.0 ) return v;
  pik_error(p,pId,"no such variable");
  return 0.0;
}

/* Convert a T_NTH token (ex: "2nd", "5th"} into a numeric value and
** return that value.  Throw an error if the value is too big.
*/
static short int pik_nth_value(Pik *p, PToken *pNth){
  int i = atoi(pNth->z);
  if( i>1000 ){
    pik_error(p, pNth, "value too big - max '1000th'");
    i = 1;
  }
  if( i==0 && pik_token_eq(pNth,"first")==0 ) i = 1;
  return i;
}

/* Search for the NTH element.
**
** If pBasis is not NULL then it should be a [] element.  Use the
** sublist of that [] element for the search.  If pBasis is not a []
** element, then throw an error.
**
** The pNth token describes the N-th search.  The pNth->eCode value
** is one more than the number of items to skip.  It is negative
** to search backwards.  If pNth->eType==T_ID, then it is the name
** of a primative time to search for.  If pNth->eType==T_LB, then
** search for a [] object.  If pNth->eType==T_LAST, then search for
** any type.
**
** Raise an error if the item is not found.
*/
static PElem *pik_find_nth(Pik *p, PElem *pBasis, PToken *pNth){
  PEList *pList;
  int i, n;
  const PClass *pClass;
  if( pBasis==0 ){
    pList = p->list;
  }else{
    pList = pBasis->pSublist;
  }
  if( pList==0 ){
    pik_error(p, pNth, "no such object");
    return 0;
  }
  if( pNth->eType==T_LAST ){
    pClass = 0;
  }else if( pNth->eType==T_LB ){
    pClass = &sublistClass;
  }else{
    pClass = pik_find_class(pNth);
    if( pClass==0 ){
      pik_error(0, pNth, "no such object type");
      return 0;
    }
  }
  n = pNth->eCode;
  if( n<0 ){
    for(i=pList->n-1; i>=0; i--){
      PElem *pElem = pList->a[i];
      if( pClass && pElem->type!=pClass ) continue;
      n++;
      if( n==0 ){ return pElem; }
    }
  }else{
    for(i=0; i<pList->n; i++){
      PElem *pElem = pList->a[i];
      if( pClass && pElem->type!=pClass ) continue;
      n--;
      if( n==0 ){ return pElem; }
    }
  }
  pik_error(p, pNth, "no such object");
  return 0;
}

/* Search for an element by name.
**
** Search in pBasis->pSublist if pBasis is not NULL.  If pBasis is NULL
** then search in p->list.
*/
static PElem *pik_find_byname(Pik *p, PElem *pBasis, PToken *pName){
  PEList *pList;
  int i, j;
  if( pBasis==0 ){
    pList = p->list;
  }else{
    pList = pBasis->pSublist;
  }
  if( pList==0 ){
    pik_error(p, pName, "no such object");
    return 0;
  }
  /* First look explicitly tagged objects */
  for(i=pList->n-1; i>=0; i--){
    PElem *pElem = pList->a[i];
    if( pElem->zName && pik_token_eq(pName,pElem->zName)==0 ){
      return pElem;
    }
  }
  /* If not found, do a second pass looking for any object containing
  ** text which exactly matches pName */
  for(i=pList->n-1; i>=0; i--){
    PElem *pElem = pList->a[i];
    for(j=0; j<pElem->nTxt; j++){
      if( pElem->aTxt[j].n==pName->n+2
       && memcmp(pElem->aTxt[j].z+1,pName->z,pName->n)==0 ){
        return pElem;
      }
    }
  }
  pik_error(p, pName, "no such object");
  return 0;
}

/* Change most of the settings for the current object to be the
** same as the pElem object, or the most recent element of the same
** type if pElem is NULL.
*/
static void pik_same(Pik *p, PElem *pOther, PToken *pErrTok){
  PElem *pElem = p->cur;
  if( p->nErr ) return;
  if( pOther==0 ){
    int i;
    for(i=(p->list ? p->list->n : 0)-1; i>=0; i--){
      pOther = p->list->a[i];
      if( pOther->type==pElem->type ) break;
    }
    if( i<0 ){
      pik_error(p, pErrTok, "no prior objects of the same type");
      return;
    }
  }
  if( pOther->nPath && pElem->type->isLine ){
    PNum dx, dy;
    int i;
    dx = p->aTPath[0].x - pOther->aPath[0].x;
    dy = p->aTPath[0].y - pOther->aPath[0].y;
    for(i=1; i<pOther->nPath; i++){
      p->aTPath[i].x = pOther->aPath[i].x + dx;
      p->aTPath[i].y = pOther->aPath[i].y + dy;
    }
    p->nTPath = pOther->nPath;
    p->mTPath = 3;
  }
  pElem->w = pOther->w;
  pElem->h = pOther->h;
  pElem->rad = pOther->rad;
  pElem->sw = pOther->sw;
  pElem->dashed = pOther->dashed;
  pElem->dotted = pOther->dashed;
  pElem->fill = pOther->fill;
  pElem->color = pOther->color;
  pElem->cw = pOther->cw;
  pElem->larrow = pOther->larrow;
  pElem->rarrow = pOther->rarrow;
  pElem->bClose = pOther->bClose;
  pElem->bChop = pOther->bChop;
  pElem->inDir = pOther->inDir;
  pElem->outDir = pOther->outDir;
}


/* Return a "Place" associated with element pElem.  If pEdge is NULL
** return the center of the object.  Otherwise, return the corner
** described by pEdge.
*/
static PPoint pik_place_of_elem(Pik *p, PElem *pElem, PToken *pEdge){
  PPoint pt;
  const PClass *pClass;
  pt.x = 0.0;
  pt.y = 0.0;
  if( pElem==0 ) return pt;
  if( pEdge==0 ){
    return pElem->ptAt;
  }
  pClass = pElem->type;
  if( pEdge->eType==T_EDGEPT || pEdge->eEdge>0 ){
    if( pClass->isLine ){
      pik_error(0, pEdge,
          "line objects have only \"start\" and \"end\" points");
      return pt;
    }
    if( pClass->xOffset==0 ){
      pt = boxOffset(p, pElem, pEdge->eEdge);
    }else{
      pt = pClass->xOffset(p, pElem, pEdge->eEdge);
    }
    pt.x += pElem->ptAt.x;
    pt.y += pElem->ptAt.y;
    return pt;
  }
  if( !pClass->isLine ){
    pik_error(0, pEdge,
          "only line objects have \"start\" and \"end\" points");
    return pt;
  }
  if( pEdge->eType==T_START ){
    return pElem->aPath[0];
  }else{
    return pElem->aPath[pElem->nPath-1];
  }
}

/* Do a linear interpolation of two positions.
*/
static PPoint pik_position_between(Pik *p, PNum x, PPoint p1, PPoint p2){
  PPoint out;
  if( x<0.0 ) x = 0.0;
  if( x>1.0 ) x = 1.0;
  out.x = p2.x*x + p1.x*(1.0 - x);
  out.y = p2.y*x + p1.y*(1.0 - x);
  return out;
}

/* Compute the position that is dist away from pt at an heading angle of r
**
** The angle is compass heading in degrees.  North is 0 (or 360).
** East is 90.  South is 180.  West is 270.  And so forth.
*/
static PPoint pik_position_at_angle(Pik *p, PNum dist, PNum r, PPoint pt){
  r *= 0.017453292519943295769;  /* degrees to radians */
  pt.x += dist*sin(r);
  pt.y += dist*cos(r);
  return pt;
}

/* Compute the position that is dist away at a compass point
*/
static PPoint pik_position_at_hdg(Pik *p, PNum dist, PToken *pD, PPoint pt){
  return pik_position_at_angle(p, dist, pik_hdg_angle[pD->eEdge], pt);
}

/* Return the coordinates for the n-th vertex of a line.
*/
static PPoint pik_nth_vertex(Pik *p, PToken *pNth, PToken *pErr, PElem *pObj){
  static const PPoint zero;
  int n;
  if( p->nErr || pObj==0 ) return p->aTPath[0];
  if( !pObj->type->isLine ){
    pik_error(p, pErr, "object is not a line");
    return zero;
  }
  n = atoi(pNth->z);
  if( n<1 || n>pObj->nPath ){
    pik_error(p, pNth, "no such vertex");
    return zero;
  }
  return pObj->aPath[n-1];
}

/* Return the value of a property of an object.
*/
static PNum pik_property_of(Pik *p, PElem *pElem, PToken *pProp){
  PNum v = 0.0;
  switch( pProp->eType ){
    case T_HEIGHT:    v = pElem->h;            break;
    case T_WIDTH:     v = pElem->w;            break;
    case T_RADIUS:    v = pElem->rad;          break;
    case T_DIAMETER:  v = pElem->rad*2.0;      break;
    case T_THICKNESS: v = pElem->sw;           break;
    case T_DASHED:    v = pElem->dashed;       break;
    case T_DOTTED:    v = pElem->dotted;       break;
    case T_FILL:      v = pElem->fill;         break;
    case T_COLOR:     v = pElem->color;        break;
    case T_X:         v = pElem->ptAt.x;       break;
    case T_Y:         v = pElem->ptAt.y;       break;
    case T_TOP:       v = pElem->bbox.ne.y;    break;
    case T_BOTTOM:    v = pElem->bbox.sw.y;    break;
    case T_LEFT:      v = pElem->bbox.sw.x;    break;
    case T_RIGHT:     v = pElem->bbox.ne.x;    break;
  }
  return v;
}

/* Compute one of the built-in functions
*/
static PNum pik_func(Pik *p, PToken *pFunc, PNum x, PNum y){
  PNum v = 0.0;
  switch( pFunc->eCode ){
    case FN_ABS:  v = v<0.0 ? -v : v;  break;
    case FN_COS:  v = cos(x);          break;
    case FN_INT:  v = rint(x);         break;
    case FN_SIN:  v = sin(x);          break;
    case FN_SQRT:
      if( x<0.0 ){
        pik_error(p, pFunc, "sqrt of negative value");
        v = 0.0;
      }else{
        v = sqrt(x);
      }
      break;
    case FN_MAX:  v = x>y ? x : y;   break;
    case FN_MIN:  v = x<y ? x : y;   break;
    default:      v = 0.0;
  }
  return v;
}

/* Attach a name to an element
*/
static void pik_elem_setname(Pik *p, PElem *pElem, PToken *pName){
  if( pElem==0 ) return;
  if( pName==0 ) return;
  free(pElem->zName);
  pElem->zName = malloc(pName->n+1);
  if( pElem->zName==0 ){
    pik_error(p,0,0);
  }else{
    memcpy(pElem->zName,pName->z,pName->n);
    pElem->zName[pName->n] = 0;
  }
  return;
}

/*
** Search for object located at *pCenter that has an xChop method.
** Return a pointer to the object, or NULL if not found.
*/
static PElem *pik_find_chopper(PEList *pList, PPoint *pCenter){
  int i;
  if( pList==0 ) return 0;
  for(i=pList->n-1; i>=0; i--){
    PElem *pElem = pList->a[i];
    if( pElem->type->xChop!=0
     && pElem->ptAt.x==pCenter->x
     && pElem->ptAt.y==pCenter->y
    ){
      return pElem;
    }else if( pElem->pSublist ){
      pElem = pik_find_chopper(pElem->pSublist,pCenter);
      if( pElem ) return pElem;
    }
  }
  return 0;
}

/*
** There is a line traveling from pFrom to pTo.
**
** If point pTo is the exact enter of a choppable object,
** then adjust pTo by the appropriate amount in the direction
** of pFrom.
*/
static void pik_autochop(Pik *p, PPoint *pFrom, PPoint *pTo){
  PElem *pElem = pik_find_chopper(p->list, pTo);
  if( pElem ){
    *pTo = pElem->type->xChop(pElem, pFrom);
  }
}

/* This routine runs after all attributes have been received
** on an element.
*/
static void pik_after_adding_attributes(Pik *p, PElem *pElem){
  int i;
  PPoint ofst;
  PNum dx, dy;

  if( p->nErr ) return;
  ofst = pik_elem_offset(p, pElem, pElem->eWith);
  dx = (pElem->with.x - ofst.x) - pElem->ptAt.x;
  dy = (pElem->with.y - ofst.y) - pElem->ptAt.y;
  if( dx!=0 || dy!=0 ){
    pik_elem_move(pElem, dx, dy);
  }

  /* For a line object with no movement specified, a single movement
  ** of the default length in the current direction
  */
  if( pElem->type->isLine && p->nTPath<2 ){
    pik_next_rpath(p, 0);
    assert( p->nTPath==2 );
    switch( pElem->inDir ){
      default:        p->aTPath[1].x += pElem->w; break;
      case DIR_DOWN:  p->aTPath[1].y -= pElem->h; break;
      case DIR_LEFT:  p->aTPath[1].x -= pElem->w; break;
      case DIR_UP:    p->aTPath[1].y += pElem->h; break;
    }
    if( strcmp(pElem->type->zName,"arc")==0 ){
      p->eDir = pElem->outDir = (pElem->inDir + (pElem->cw ? 1 : 3))%4;
      switch( pElem->outDir ){
        default:        p->aTPath[1].x += pElem->w; break;
        case DIR_DOWN:  p->aTPath[1].y -= pElem->h; break;
        case DIR_LEFT:  p->aTPath[1].x -= pElem->w; break;
        case DIR_UP:    p->aTPath[1].y += pElem->h; break;
      }
    }
  }

  /* Compute final bounding box, entry and exit points, center
  ** point (ptAt) and path for the element
  */
  pik_bbox_init(&pElem->bbox);
  if( pElem->type->isLine ){
    pElem->aPath = malloc( sizeof(PPoint)*p->nTPath );
    if( pElem->aPath==0 ){
      pik_error(p, 0, 0);
      pElem->nPath = 0;
    }else{
      pElem->nPath = p->nTPath;
      for(i=0; i<p->nTPath; i++){
        pElem->aPath[i] = p->aTPath[i];
        pik_bbox_addpt(&pElem->bbox, &pElem->aPath[i]);
      }
    }

    /* "chop" processing:
    ** If the line goes to the center of an object with an
    ** xChop method, then use the xChop method to trim the line.
    */
    if( pElem->bChop && pElem->nPath>=2 ){
      int n = pElem->nPath;
      pik_autochop(p, &pElem->aPath[n-2], &pElem->aPath[n-1]);
      pik_autochop(p, &pElem->aPath[1], &pElem->aPath[0]);
    }

    pElem->ptEnter = p->aTPath[0];
    pElem->ptExit = p->aTPath[p->nTPath-1];

    /* Compute the center of the line based on the bounding box over
    ** the vertexes */
    pElem->ptAt.x = (pElem->bbox.ne.x + pElem->bbox.sw.x)/2.0;
    pElem->ptAt.y = (pElem->bbox.ne.y + pElem->bbox.sw.y)/2.0;

    /* Reset the width and height of the object to be the width and height
    ** of the bounding box over vertexes */
    pElem->w = pElem->bbox.ne.x - pElem->bbox.sw.x;
    pElem->h = pElem->bbox.ne.y - pElem->bbox.sw.y;

    /* If this is a polygon (if it has the "close" attribute), then
    ** adjust the exit point */
    if( pElem->bClose ){
      pik_elem_set_exit(p, pElem, pElem->inDir);
    }
  }else{
    PNum w2 = pElem->w/2.0;
    PNum h2 = pElem->h/2.0;
    pElem->ptEnter = pElem->ptAt;
    pElem->ptExit = pElem->ptAt;
    switch( pElem->inDir ){
      default:         pElem->ptEnter.x -= w2;  break;
      case DIR_LEFT:   pElem->ptEnter.x += w2;  break;
      case DIR_UP:     pElem->ptEnter.y -= h2;  break;
      case DIR_DOWN:   pElem->ptEnter.y += h2;  break;
    }
    switch( pElem->outDir ){
      default:         pElem->ptExit.x += w2;  break;
      case DIR_LEFT:   pElem->ptExit.x -= w2;  break;
      case DIR_UP:     pElem->ptExit.y += h2;  break;
      case DIR_DOWN:   pElem->ptExit.y -= h2;  break;
    }
    pElem->bbox.sw.x = pElem->ptAt.x - w2;
    pElem->bbox.sw.y = pElem->ptAt.y - h2;
    pElem->bbox.ne.x = pElem->ptAt.x + w2;
    pElem->bbox.ne.y = pElem->ptAt.y + h2;
  }
  p->eDir = pElem->outDir;
}

/* Show basic information about each element as a comment in the
** generated HTML.  Used for testing and debugging.  Activated
** by the (undocumented) "debug = 1;"
** command.
*/
static void pik_elem_render(Pik *p, PElem *pElem){
  char *zDir;
  if( pElem==0 ) return;
  pik_append(p,"<!-- ", -1);
  if( pElem->zName ){
    pik_append_text(p, pElem->zName, -1, 0);
    pik_append(p, ": ", 2);
  }
  pik_append_text(p, pElem->type->zName, -1, 0);
  if( pElem->nTxt ){
    pik_append(p, " \"", 2);
    pik_append_text(p, pElem->aTxt[0].z+1, pElem->aTxt[0].n-2, 1);
    pik_append(p, "\"", 1);
  }
  pik_append_num(p, " w=", pElem->w);
  pik_append_num(p, " h=", pElem->h);
  pik_append_point(p, " center=", &pElem->ptAt);
  pik_append_point(p, " enter=", &pElem->ptEnter);
  switch( pElem->outDir ){
    default:        zDir = " right";  break;
    case DIR_LEFT:  zDir = " left";   break;
    case DIR_UP:    zDir = " up";     break;
    case DIR_DOWN:  zDir = " down";   break;
  }
  pik_append_point(p, " exit=", &pElem->ptExit);
  pik_append(p, zDir, -1);
  pik_append(p, " -->\n", -1);
}

/* Render a list of elements
*/
void pik_elist_render(Pik *p, PEList *pEList){
  int i;
  int iNextLayer = 0;
  int iThisLayer;
  int bMoreToDo;
  int mDebug = (int)pik_value(p, "debug", 5, 0);
  do{
    bMoreToDo = 0;
    iThisLayer = iNextLayer;
    iNextLayer = 0x7fffffff;
    for(i=0; i<pEList->n; i++){
      PElem *pElem = pEList->a[i];
      if( pElem->iLayer>iThisLayer ){
        if( pElem->iLayer<iNextLayer ) iNextLayer = pElem->iLayer;
        bMoreToDo = 1;
        continue; /* Defer until another round */
      }else if( pElem->iLayer<iThisLayer ){
        continue;
      }
      void (*xRender)(Pik*,PElem*);
      if( mDebug & 1 ) pik_elem_render(p, pElem);
      xRender = pElem->type->xRender;
      if( xRender ){
        xRender(p, pElem);
      }
      if( pElem->pSublist ){
        pik_elist_render(p, pElem->pSublist);
      }
    }
  }while( bMoreToDo );
}

/* Recompute key layout parameters from variables. */
static void pik_compute_layout_settings(Pik *p){
  PNum thickness;  /* Line thickness */
  PNum wArrow;     /* Width of arrowheads */

  /* Set up rendering parameters */
  if( p->bLayoutVars ) return;
  thickness = pik_value(p,"thickness",9,0);
  if( thickness<=0.01 ) thickness = 0.01;
  wArrow = 0.5*pik_value(p,"arrowwid",8,0);
  p->wArrow = wArrow/thickness;
  p->hArrow = pik_value(p,"arrowht",7,0)/thickness;
  p->rScale = 144.0*pik_value(p,"scale",5,0);
  if( p->rScale<5.0 ) p->rScale = 5.0;
  p->fontScale = pik_value(p,"fontscale",9,0);
  if( p->fontScale<=0.0 ) p->fontScale = 1.0;
  p->fontScale *= p->rScale/144.0;
  p->charWidth = pik_value(p,"charwid",7,0)*p->fontScale;
  p->charHeight = pik_value(p,"charht",6,0)*p->fontScale;
  p->bLayoutVars = 1;
}

/* Render a list of elements.  Write the SVG into p->zOut.
** Delete the input element_list before returnning.
*/
static void pik_render(Pik *p, PEList *pEList){
  int i, j;
  if( pEList==0 ) return;
  if( p->nErr==0 ){
    PNum thickness;  /* Stroke width */
    PNum margin;     /* Extra bounding box margin */
    PNum leftmargin; /* Extra bounding box area on the left */
    PNum w, h;       /* Drawing width and height */
    PNum wArrow;

    /* Set up rendering parameters */
    pik_compute_layout_settings(p);
    thickness = pik_value(p,"thickness",9,0);
    if( thickness<=0.01 ) thickness = 0.01;
    margin = pik_value(p,"margin",6,0);
    margin += thickness;
    leftmargin = pik_value(p,"leftmargin",10,0);
    wArrow = p->wArrow*thickness;

    /* Compute a bounding box over all objects so that we can know
    ** how big to declare the SVG canvas */
    pik_bbox_init(&p->bbox);
    for(i=0; i<pEList->n; i++){
      PElem *pElem = pEList->a[i];
      pik_bbox_addbox(&p->bbox, &pElem->bbox);

      /* Expand the bounding box to account for arrowheads on lines */
      if( pElem->type->isLine && pElem->nPath>0 ){
        if( pElem->larrow ){
          pik_bbox_addellipse(&p->bbox, pElem->aPath[0].x, pElem->aPath[0].y,
                              wArrow, wArrow);
        }
        if( pElem->rarrow ){
          j = pElem->nPath-1;
          pik_bbox_addellipse(&p->bbox, pElem->aPath[j].x, pElem->aPath[j].y,
                              wArrow, wArrow);
        }
      }
    }

    /* Expand the bounding box slightly to account for line thickness
    ** and the optional "margin = EXPR" setting. */
    p->bbox.ne.x += margin;
    p->bbox.ne.y += margin;
    p->bbox.sw.x -= margin + leftmargin;
    p->bbox.sw.y -= margin;

    /* Output the SVG */
    pik_append(p, "<svg",4);
    if( p->zClass ){
      pik_append(p, " class=\"", -1);
      pik_append(p, p->zClass, -1);
      pik_append(p, "\"", 1);
    }
    w = p->bbox.ne.x - p->bbox.sw.x;
    h = p->bbox.ne.y - p->bbox.sw.y;
    p->wSVG = (int)(p->rScale*w);
    p->hSVG = (int)(p->rScale*h);
    pik_append_dis(p, " width=\"", w, "\"");
    pik_append_dis(p, " height=\"",h,"\">\n");
    pik_elist_render(p, pEList);
    pik_append(p,"</svg>\n", -1);
  }else{
    p->wSVG = -1;
    p->hSVG = -1;
  }
  pik_elist_free(p, pEList);
}



/*
** An array of this structure defines a list of keywords.
*/
typedef struct PikWord {
  char *zWord;             /* Text of the keyword */
  unsigned char nChar;     /* Length of keyword text in bytes */
  unsigned char eType;     /* Token code */
  unsigned char eCode;     /* Extra code for the token */
  unsigned char eEdge;     /* CP_* code for corner/edge keywords */
} PikWord;

/*
** Keywords
*/
static const PikWord pik_keywords[] = {
  { "above",      5,   T_ABOVE,     0,         0       },
  { "abs",        3,   T_FUNC1,     FN_ABS,    0       },
  { "aligned",    7,   T_ALIGNED,   0,         0       },
  { "and",        3,   T_AND,       0,         0       },
  { "as",         2,   T_AS,        0,         0       },
  { "at",         2,   T_AT,        0,         0       },
  { "below",      5,   T_BELOW,     0,         0       },
  { "between",    7,   T_BETWEEN,   0,         0       },
  { "bold",       4,   T_BOLD,      0,         0       },
  { "bot",        3,   T_EDGEPT,    0,         CP_S    },
  { "bottom",     6,   T_BOTTOM,    0,         CP_S    },
  { "c",          1,   T_EDGEPT,    0,         CP_C    },
  { "ccw",        3,   T_CCW,       0,         0       },
  { "center",     6,   T_CENTER,    0,         0       },
  { "chop",       4,   T_CHOP,      0,         0       },
  { "close",      5,   T_CLOSE,     0,         0       },
  { "color",      5,   T_COLOR,     0,         0       },
  { "cos",        3,   T_FUNC1,     FN_COS,    0       },
  { "cw",         2,   T_CW,        0,         0       },
  { "dashed",     6,   T_DASHED,    0,         0       },
  { "diameter",   8,   T_DIAMETER,  0,         0       },
  { "dotted",     6,   T_DOTTED,    0,         0       },
  { "down",       4,   T_DOWN,      DIR_DOWN,  0       },
  { "e",          1,   T_EDGEPT,    0,         CP_E    },
  { "east",       4,   T_EDGEPT,    0,         CP_E    },
  { "end",        3,   T_END,       0,         0       },
  { "even",       4,   T_EVEN,      0,         0       },
  { "fill",       4,   T_FILL,      0,         0       },
  { "first",      5,   T_NTH,       0,         0       },
  { "fit",        3,   T_FIT,       0,         0       },
  { "from",       4,   T_FROM,      0,         0       },
  { "heading",    7,   T_HEADING,   0,         0       },
  { "height",     6,   T_HEIGHT,    0,         0       },
  { "ht",         2,   T_HEIGHT,    0,         0       },
  { "in",         2,   T_IN,        0,         0       },
  { "int",        3,   T_FUNC1,     FN_INT,    0       },
  { "invis",      5,   T_INVIS,     0,         0       },
  { "invisible",  9,   T_INVIS,     0,         0       },
  { "italic",     6,   T_ITALIC,    0,         0       },
  { "last",       4,   T_LAST,      0,         0       },
  { "left",       4,   T_LEFT,      DIR_LEFT,  CP_W    },
  { "ljust",      5,   T_LJUST,     0,         0       },
  { "max",        3,   T_FUNC2,     FN_MAX,    0       },
  { "min",        3,   T_FUNC2,     FN_MIN,    0       },
  { "n",          1,   T_EDGEPT,    0,         CP_N    },
  { "ne",         2,   T_EDGEPT,    0,         CP_NE   },
  { "north",      5,   T_EDGEPT,    0,         CP_N    },
  { "nw",         2,   T_EDGEPT,    0,         CP_NW   },
  { "of",         2,   T_OF,        0,         0       },
  { "print",      5,   T_PRINT,     0,         0       },
  { "rad",        3,   T_RADIUS,    0,         0       },
  { "radius",     6,   T_RADIUS,    0,         0       },
  { "right",      5,   T_RIGHT,     DIR_RIGHT, CP_E    },
  { "rjust",      5,   T_RJUST,     0,         0       },
  { "s",          1,   T_EDGEPT,    0,         CP_S    },
  { "same",       4,   T_SAME,      0,         0       },
  { "se",         2,   T_EDGEPT,    0,         CP_SE   },
  { "sin",        3,   T_FUNC1,     FN_SIN,    0       },
  { "south",      5,   T_EDGEPT,    0,         CP_S    },
  { "sqrt",       4,   T_FUNC1,     FN_SQRT,   0       },
  { "start",      5,   T_START,     0,         0       },
  { "sw",         2,   T_EDGEPT,    0,         CP_SW   },
  { "t",          1,   T_TOP,       0,         CP_N    },
  { "the",        3,   T_THE,       0,         0       },
  { "then",       4,   T_THEN,      0,         0       },
  { "thickness",  9,   T_THICKNESS, 0,         0       },
  { "to",         2,   T_TO,        0,         0       },
  { "top",        3,   T_TOP,       0,         CP_N    },
  { "until",      5,   T_UNTIL,     0,         0       },
  { "up",         2,   T_UP,        DIR_UP,    0       },
  { "vertex",     6,   T_VERTEX,    0,         0       },
  { "w",          1,   T_EDGEPT,    0,         CP_W    },
  { "way",        3,   T_WAY,       0,         0       },
  { "west",       4,   T_EDGEPT,    0,         CP_W    },
  { "wid",        3,   T_WIDTH,     0,         0       },
  { "width",      5,   T_WIDTH,     0,         0       },
  { "with",       4,   T_WITH,      0,         0       },
  { "x",          1,   T_X,         0,         0       },
  { "y",          1,   T_Y,         0,         0       },
};

/*
** Search a PikWordlist for the given keyword.  A pointer to the
** element found.  Or return 0 if not found.
*/
static const PikWord *pik_find_word(
  const char *zIn,              /* Word to search for */
  int n,                        /* Length of zIn */
  const PikWord *aList,         /* List to search */
  int nList                     /* Number of entries in aList */
){
  int first = 0;
  int last = nList-1;
  while( first<=last ){
    int mid = (first + last)/2;
    int sz = aList[mid].nChar;
    int c = strncmp(zIn, aList[mid].zWord, sz<n ? sz : n);
    if( c==0 ){
      c = n - sz;
      if( c==0 ) return &aList[mid];
    }
    if( c<0 ){
      last = mid-1;
    }else{
      first = mid+1;
    }
  }
  return 0;
}


/*
** Return the length of next token.  The token starts on
** the pToken->z character.  Fill in other fields of the
** pToken object as appropriate.
*/
static int pik_token_length(PToken *pToken){
  const unsigned char *z = (const unsigned char*)pToken->z;
  int i;
  unsigned char c, c2;
  switch( z[0] ){
    case '\\': {
      pToken->eType = T_WHITESPACE;
      for(i=1; z[i]=='\r' || z[i]==' ' || z[i]=='\t'; i++){}
      if( z[i]=='\n'  ) return i+1;
      pToken->eType = T_ERROR;
      return 1;
    }
    case ';':
    case '\n': {
      pToken->eType = T_EOL;
      return 1;
    }
    case '"': {
      for(i=1; (c = z[i])!=0; i++){
        if( c=='\\' ){ i++; continue; }
        if( c=='"' ){
          pToken->eType = T_STRING;
          return i+1;
        }
      }
      pToken->eType = T_ERROR;
      return i;
    }
    case ' ':
    case '\t':
    case '\f':
    case '\r': {
      for(i=1; (c = z[i])==' ' || c=='\t' || c=='\r' || c=='\t'; i++){}
      pToken->eType = T_WHITESPACE;
      return i;
    }
    case '#': {
      for(i=1; (c = z[i])!=0 && c!='\n'; i++){}
      pToken->eType = T_WHITESPACE;
      return i;
    }
    case '/': {
      if( z[1]=='*' ){
        for(i=2; z[i]!=0 && (z[i]!='*' || z[i+1]!='/'); i++){}
        if( z[i]=='*' ){
          pToken->eType = T_WHITESPACE;
          return i+2;
        }else{
          pToken->eType = T_ERROR;
          return i;
        }
      }else if( z[1]=='/' ){
        for(i=2; z[i]!=0 && z[i]!='\n'; i++){}
        if( z[i]!=0 ) i++;
        pToken->eType = T_WHITESPACE;
        return i;
      }else if( z[1]=='=' ){
        pToken->eType = T_ASSIGN;
        pToken->eCode = T_SLASH;
        return 2;
      }else{
        pToken->eType = T_SLASH;
        return 1;
      }
    }
    case '+': {
      if( z[1]=='=' ){
        pToken->eType = T_ASSIGN;
        pToken->eCode = T_PLUS;
        return 2;
      }
      pToken->eType = T_PLUS;
      return 1;
    }
    case '*': {
      if( z[1]=='=' ){
        pToken->eType = T_ASSIGN;
        pToken->eCode = T_STAR;
        return 2;
      }
      pToken->eType = T_STAR;
      return 1;
    }
    case '%': {   pToken->eType = T_PERCENT; return 1; }
    case '(': {   pToken->eType = T_LP;      return 1; }
    case ')': {   pToken->eType = T_RP;      return 1; }
    case '[': {   pToken->eType = T_LB;      return 1; }
    case ']': {   pToken->eType = T_RB;      return 1; }
    case ',': {   pToken->eType = T_COMMA;   return 1; }
    case ':': {   pToken->eType = T_COLON;   return 1; }
    case '=': {   pToken->eType = T_ASSIGN;
                  pToken->eCode = T_ASSIGN;  return 1; }
    case '-': {
      if( z[1]=='>' ){
        pToken->eType = T_RARROW;
        return 2;
      }else if( z[1]=='=' ){
        pToken->eType = T_ASSIGN;
        pToken->eCode = T_MINUS;
        return 2;
      }else{
        pToken->eType = T_MINUS;
        return 1;
      }
    }
    case '<': { 
      if( z[1]=='-' ){
         if( z[2]=='>' ){
           pToken->eType = T_LRARROW;
           return 3;
         }else{
           pToken->eType = T_LARROW;
           return 2;
         }
      }else{
        pToken->eType = T_ERROR;
         return 1;
      }
    }
    default: {
      c = z[0];
      if( c=='.' ){
        unsigned char c1 = z[1];
        if( islower(c1) ){
          const PikWord *pFound;
          for(i=2; (c = z[i])>='a' && c<='z'; i++){}
          pFound = pik_find_word((const char*)z+1, i-1,
                                    pik_keywords, count(pik_keywords));
          if( pFound && (pFound->eType==T_EDGEPT || pFound->eEdge>0) ){
            pToken->eType = T_DOT_E;
          }else{
            pToken->eType = T_DOT_L;
          }
          return 1;
        }else if( isdigit(c1) ){
          i = 0;
          /* no-op.  Fall through to number handling */
        }else if( isupper(c1) ){
          for(i=2; (c = z[i])!=0 && (isalnum(c) || c=='_'); i++){}
          pToken->eType = T_DOT_U;
          return 1;
        }else{
          pToken->eType = T_ERROR;
          return 1;
        }
      }
      if( (c>='0' && c<='9') || c=='.' ){
        int nDigit;
        int isInt = 1;
        if( c!='.' ){
          nDigit = 1;
          for(i=1; (c = z[i])>='0' && c<='9'; i++){ nDigit++; }
          if( i==1 && (c=='x' || c=='X') ){
            for(i=3; (c = z[i])!=0 && isxdigit(c); i++){}
            pToken->eType = T_NUMBER;
            return i;
          }
        }else{
          isInt = 0;
          nDigit = 0;
        }
        if( c=='.' ){
          isInt = 0;
          for(i++; (c = z[i])>='0' && c<='9'; i++){ nDigit++; }
        }
        if( nDigit==0 ){
          pToken->eType = T_ERROR;
          return i;
        }
        if( c=='e' || c=='E' ){
          i++;
          c2 = z[i];
          if( c2=='+' || c2=='-' ){
            i++;
            c2 = z[i];
          }
          if( c2<'0' || c>'9' ){
            /* This is not an exp */
            i -= 2;
          }else{
            i++;
            isInt = 0;
            while( (c = z[i])>=0 && c<='9' ){ i++; }
          }
        }
        c2 = z[i+1];
        if( isInt ){
          if( (c=='t' && c2=='h')
           || (c=='r' && c2=='d')
           || (c=='n' && c2=='d')
           || (c=='s' && c2=='t')
          ){
            pToken->eType = T_NTH;
            return i+2;
          }
        }
        if( (c=='i' && c2=='n')
         || (c=='c' && c2=='m')
         || (c=='m' && c2=='m')
         || (c=='p' && c2=='t')
         || (c=='p' && c2=='x')
         || (c=='p' && c2=='c')
        ){
          i += 2;
        }
        pToken->eType = T_NUMBER;
        return i;
      }else if( islower(c) || c=='_' || c=='$' || c=='@' ){
        const PikWord *pFound;
        for(i=1; (c =  z[i])!=0 && (isalnum(c) || c=='_'); i++){}
        pFound = pik_find_word((const char*)z, i,
                               pik_keywords, count(pik_keywords));
        if( pFound ){
          pToken->eType = pFound->eType;
          pToken->eCode = pFound->eCode;
          pToken->eEdge = pFound->eEdge;
          return i;
        }
        pToken->n = i;
        if( pik_find_class(pToken)!=0 ){
          pToken->eType = T_CLASSNAME;
        }else{
          pToken->eType = T_ID;
        }
        return i;
      }else if( c>='A' && c<='Z' ){
        for(i=1; (c =  z[i])!=0 && (isalnum(c) || c=='_'); i++){}
        pToken->eType = T_PLACENAME;
        return i;
      }else{
        pToken->eType = T_ERROR;
        return 1;
      }
    }
  }
}

/*
** Return a pointer to the next non-whitespace token after pThis.
** This is used to help form error messages.
*/
static PToken pik_next_semantic_token(Pik *p, PToken *pThis){
  PToken x;
  int sz;
  int i = pThis->n;
  memset(&x, 0, sizeof(x));
  x.z = pThis->z;
  while(1){
    x.z = pThis->z + i;
    sz = pik_token_length(&x);
    if( x.eType!=T_WHITESPACE ){
      x.n = sz;
      return x;
    }
    i += sz;
  }
}

/*
** Parse the PIKCHR script contained in zText[].  Return a rendering.  Or
** if an error is encountered, return the error text.  The error message
** is HTML formatted.  So regardless of what happens, the return text
** is safe to be insertd into an HTML output stream.
**
** If pnWidth and pnHeight are NULL, then this routine writes the
** width and height of the <SVG> object into the integers that they
** point to.  A value of -1 is written if an error is seen.
**
** If zClass is not NULL, then it is a class name to be included in
** the <SVG> markup.
**
** The returned string is contained in memory obtained from malloc()
** and should be released by the caller.
*/
char *pikchr(
  const char *zText,     /* Input PIKCHR source text.  zero-terminated */
  const char *zClass,    /* Add class="%s" to <svg> markup */
  unsigned int mFlags,   /* Flags used to influence rendering behavior */
  int *pnWidth,          /* Write width of <svg> here, if not NULL */
  int *pnHeight          /* Write height here, if not NULL */
){
  int i;
  int sz;
  PToken token;
  Pik s;
  yyParser sParse;

  memset(&s, 0, sizeof(s));
  s.zIn = zText;
  s.nIn = (unsigned int)strlen(zText);
  s.eDir = DIR_RIGHT;
  s.zClass = zClass;
  pik_parserInit(&sParse, &s);
#if 0
  pik_parserTrace(stdout, "parser: ");
#endif
  for(i=0; zText[i] && s.nErr==0; i+=sz){
    token.eCode = 0;
    token.eEdge = 0;
    token.z = zText + i;
    sz = pik_token_length(&token);
    if( token.eType==T_WHITESPACE ){
      /* no-op */
    }else if( sz>1000 ){
      token.n = 1;
      pik_error(&s, &token, "token is too long - max length 1000 bytes");
      break;
    }else if( token.eType==T_ERROR ){
      token.n = (unsigned short)(sz & 0xffff);
      pik_error(&s, &token, "unrecognized token");
      break;
    }else{
#if 0
      printf("******** Token %s (%d): \"%.*s\" **************\n",
             yyTokenName[token.eType], token.eType,
             isspace(token.z[0]) ? 0 : token.n, token.z);
#endif
      token.n = (unsigned short)(sz & 0xffff);
      pik_parser(&sParse, token.eType, token);
    }
  }
  if( s.nErr==0 ){
    memset(&token,0,sizeof(token));
    token.z = zText;
    pik_parser(&sParse, 0, token);
  }
  pik_parserFinalize(&sParse);
  while( s.pVar ){
    PVar *pNext = s.pVar->pNext;
    free(s.pVar);
    s.pVar = pNext;
  }
  if( pnWidth ) *pnWidth = s.nErr ? -1 : s.wSVG;
  if( pnHeight ) *pnHeight = s.nErr ? -1 : s.hSVG;
  if( s.zOut ){
    s.zOut[s.nOut] = 0;
    s.zOut = realloc(s.zOut, s.nOut+1);
  }
  return s.zOut;
}

#if defined(PIKCHR_FUZZ)
#include <stdint.h>
int LLVMFuzzerTestOneInput(const uint8_t *aData, size_t nByte){
  int w,h;
  char *zIn, *zOut;
  zIn = malloc( nByte + 1 );
  if( zIn==0 ) return 0;
  memcpy(zIn, aData, nByte);
  zIn[nByte] = 0;
  zOut = pikchr(zIn, "pikchr", 0, &w, &h);
  free(zIn);
  free(zOut);
  return 0;
}
#endif /* PIKCHR_FUZZ */

#if defined(PIKCHR_SHELL)
/* Texting interface
**
** Generate HTML on standard output that displays both the original
** input text and the rendered SVG for all files named on the command
** line.
*/
int main(int argc, char **argv){
  int i;
  printf(
    "<!DOCTYPE html>\n"
    "<html lang=\"en-US\">\n"
    "<head>\n<title>PIKCHR Test</title>\n"
    "<meta charset=\"utf-8\">\n"
    "</head>\n"
    "<body>\n"
  );
  for(i=1; i<argc; i++){
    FILE *in;
    size_t sz;
    char *zIn;
    char *zOut;
    char *z, c;
    int j;
    int w, h;

    printf("<h1>File %s</h1>\n", argv[i]);
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
    printf("<p>Source text:</p>\n<blockquote><pre>\n");
    z = zIn;
    while( z[0]!=0 ){
      for(j=0; (c = z[j])!=0 && c!='<' && c!='>' && c!='&'; j++){}
      if( j ) printf("%.*s", j, z);
      z += j+1;
      j = -1;
      if( c=='<' ){
        printf("&lt;");
      }else if( c=='>' ){
        printf("&gt;");
      }else if( c=='&' ){
        printf("&amp;");
      }else if( c==0 ){
        break;
      }
    }
    printf("</pre></blockquote>\n");
    zOut = pikchr(zIn, "pikchr", 0, &w, &h);
    free(zIn);
    if( zOut ){
      if( w<0 ){
        printf("<p>ERROR:</p>\n");
      }else{
        printf("<p>Output size: %d by %d</p>\n", w, h);
      }
      printf("<div style='border:2px solid gray;'>\n%s</div>\n", zOut);
      free(zOut);
    }
  }
  printf("</body></html>\n");
  return 0; 
}
#endif /* PIKCHR_SHELL */

} // end %code
