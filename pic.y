%name pic_parser

%include {

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include "pic.h"

typedef struct Pic Pic;
typedef struct PItem PItem;
struct PItem {
  int eType;
  PItem *pNext, *pPrev;
};
struct Pic {
  PItem *pList;
};


int pic_int(double r){
  int i = (int)r;
  return i;
}

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
expr(A) ::= expr(X) SLASH expr(Y). {A = Y==0.0 ? 0.0 : X/Y;}
expr(A) ::= expr(X) PERCENT expr(Y).  
    {A = pic_int(Y)!=0 ? (double)(pic_int(X) % pic_int(Y)) : 0; }
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
expr(A) ::= ID.             {A = 0.0;}
expr(A) ::= NUMBER.         {A = 0.0;}
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


%include {

#define T_WHITESPACE 1000
#define T_ERROR      1001

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
  { "box",        3,   T_BOX       },
  { "by",         2,   T_BY        },
  { "center",     6,   T_CENTER    },
  { "chop",       4,   T_CHOP      },
  { "circle",     6,   T_CIRCLE    },
  { "cos",        3,   T_COS       },
  { "dashed",     6,   T_DASHED    },
  { "diam",       4,   T_DIAMETER  },
  { "diameter",   8,   T_DIAMETER  },
  { "dotted",     6,   T_DOTTED    },
  { "down",       4,   T_DOWN      },
  { "ellipse",    7,   T_ELLIPSE   },
  { "exp",        3,   T_EXP       },
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
  { "outline",    7,   T_OUTLINE   },
  { "rad",        3,   T_RADIUS    },
  { "radius",     6,   T_RADIUS    },
  { "right",      5,   T_RIGHT     },
  { "rjust",      5,   T_RJUST     },
  { "same",       4,   T_SAME      },
  { "shaded",     6,   T_SHADED    },
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
        *peType = T_COLOR;
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
static void pic_parse(Pic *p, const char *zText){
  int i;
  int sz;
  int eType;
  yyParser sParse;
  pic_parserInit(&sParser, p);
  for(i=0; zText[i]; i+=sz){
    sz = pic_token_length(zText+i, &eType);
    if( eType==T_ERROR ){
      printf("Unknown token at position %d: \"%.*s\"\n", i, sz, zText+i);
      break;
    }else if( eType!=T_WHITESPACE ){
      pic_parser(&sParse, eType);
    }
  }
  pic_parser(&sParse, 0);
  pic_parserReset(&sParser);
}

static char *read_file(const char *zFilename){
  FILE *in;
  size_t sz;
  char *z;
  in = fopen(zFilename, "rb");
  if( in==0 ){
    fprintf(stderr, "cannot open \"%s\"\n", zFilename);
    return 0;
  }
  fseek(in, 0, SEEK_END);
  sz = ftell(in);
  rewind(in);
  z = malloc( sz+1 );
  if( z==0 ){
    fprintf(stderr, "failed to allocate %d bytes\n", (int)sz);
    fclose(in);
    return 0;
  }
  sz = fread(z, 1, sz, in);
  z[sz] = 0;
  fclose(in);
  return z;
}

int main(int argc, char **argv){
  Pic s;
  int i;
  for(i=1; i<argc; i++){
    char *z = read_file(argv[i]);
    if( z==0 ) continue;
    pic_parse(&s, z);
    free(z);
  }
  return 0; 
}

} // end %include
