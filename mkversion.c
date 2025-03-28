/*
** This C program generates the "VERSION.h" header file from information
** extracted out of the "manifest", "manifest.uuid", and "VERSION" files.
** Call this program with three arguments:
**
**     ./a.out manifest.uuid manifest VERSION
**
** Note that the manifest.uuid and manifest files are generated by Fossil.
**
** The output becomes the "VERSION.h" file.  The output is a C-language
** header that contains #defines for various properties of the build:
**
**   MANIFEST_UUID              These values are text strings that
**   MANIFEST_VERSION           identify the Fossil check-in to which
**                              the source tree belongs.  They do not
**                              take into account any uncommitted edits.
**
**   MANIFEST_DATE              The date/time of the source-code check-in
**   MANIFEST_YEAR              in various formats.
**   MANIFEST_NUMERIC_DATE
**   MANIFEST_NUMERIC_TIME
**
**   RELEASE_VERSION            The version number (from the VERSION source
**   RELEASE_VERSION_NUMBER     file) in various format.
**   RELEASE_RESOURCE_VERSION
**
** New #defines may be added in the future.
*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <time.h>

#if defined(_MSC_VER) && (_MSC_VER < 1800) /* MSVS 2013 */
#  define strtoll _strtoi64
#endif

/* These macros are provided to \"stringify\" the value of the define
** for those options in which the value is meaningful. */
#define CTIMEOPT_VAL_(opt) #opt
#define CTIMEOPT_VAL(opt) CTIMEOPT_VAL_(opt)


static FILE *open_for_reading(const char *zFilename){
  FILE *f = fopen(zFilename, "r");
  if( f==0 ){
    fprintf(stderr, "cannot open \"%s\" for reading\n", zFilename);
    exit(1);
  }
  return f;
}

/*
** Given an arbitrary-length input string key zIn, generate
** an N-byte hexadecimal hash of that string into zOut.
*/
static void hash(const char *zIn, int N, char *zOut){
  unsigned char i, j, t;
  int m, n;
  unsigned char s[256];
  for(m=0; m<256; m++){ s[m] = m; }
  for(j=0, m=n=0; m<256; m++, n++){
    j += s[m] + zIn[n];
    if( zIn[n]==0 ){ n = -1; }
    t = s[j];
    s[j] = s[m];
    s[m] = t;
  }
  i = j = 0;
  for(n=0; n<N-2; n+=2){
    i++;
    t = s[i];
    j += t;
    s[i] = s[j];
    s[j] = t;
    t += s[i];
    zOut[n] = "0123456789abcdef"[(t>>4)&0xf];
    zOut[n+1] = "0123456789abcdef"[t&0xf];
  }
  zOut[n] = 0;
}

int main(int argc, char *argv[]){
    FILE *m,*u,*v;
    char *z;
#if defined(__DMC__)            /* e.g. 0x857 */
    int i = 0;
#endif
    int j = 0, x = 0, d = 0;
    size_t n;
    int vn[3];
    char b[1000];
    char vx[1000];
    if( argc!=4 ){
      fprintf(stderr, "Usage: %s manifest.uuid manifest VERSION\n", argv[0]);
      exit(1);
    }
    memset(b,0,sizeof(b));
    memset(vx,0,sizeof(vx));
    u = open_for_reading(argv[1]);
    if( fgets(b, sizeof(b)-1,u)==0 ){
      fprintf(stderr, "malformed manifest.uuid file: %s\n", argv[1]);
      exit(1);
    }
    fclose(u);
    for(z=b; z[0] && z[0]!='\r' && z[0]!='\n'; z++){}
    *z = 0;
    printf("#define MANIFEST_UUID \"%s\"\n",b);
    printf("#define MANIFEST_VERSION \"[%10.10s]\"\n",b);
    m = open_for_reading(argv[2]);
    while(b ==  fgets(b, sizeof(b)-1,m)){
      if(0 == strncmp("D ",b,2)){
        int k, n;
        char zDateNum[30];
        printf("#define MANIFEST_DATE \"%.10s %.8s\"\n",b+2,b+13);
        printf("#define MANIFEST_YEAR \"%.4s\"\n",b+2);
        n = 0;
        for(k=0; k<19; k++){
          if( isdigit(b[k+2]) ) zDateNum[n++] = b[k+2];
        }
        zDateNum[n] = 0;
        printf("#define MANIFEST_ISODATE \"%s\"\n", zDateNum);
        n = 0;
        for(k=0; k<10; k++){
          if( isdigit(b[k+2]) ) zDateNum[n++] = b[k+2];
        }
        zDateNum[n] = 0;
        printf("#define MANIFEST_NUMERIC_DATE %s\n", zDateNum);
        n = 0;
        for(k=0; k<8; k++){
          if( isdigit(b[k+13]) ) zDateNum[n++] = b[k+13];
        }
        zDateNum[n] = 0;
        for(k=0; zDateNum[k]=='0'; k++){}
        printf("#define MANIFEST_NUMERIC_TIME %s\n", zDateNum+k);
      }
    }
    fclose(m);
    v = open_for_reading(argv[3]);
    if( fgets(b, sizeof(b)-1,v)==0 ){
      fprintf(stderr, "malformed VERSION file: %s\n", argv[3]);
      exit(1);
    }
    fclose(v);
    for(z=b; z[0] && z[0]!='\r' && z[0]!='\n'; z++){}
    *z = 0;
    printf("#define RELEASE_VERSION \"%s\"\n", b);
    z=b;
    vn[0] = vn[1] = vn[2] = 0;
    while(1){
      if( z[0]>='0' && z[0]<='9' ){
        x = x*10 + z[0] - '0';
      }else{
        if( j<3 ) vn[j++] = x;
        x = 0;
        if( z[0]==0 ) break;
      }
      z++;
    }
    for(z=vx; z[0]=='0'; z++){}
    printf("#define RELEASE_VERSION_NUMBER %d%02d%02d\n", vn[0], vn[1], vn[2]);
    memset(vx,0,sizeof(vx));
    strcpy(vx,b);
    for(z=vx; z[0]; z++){
      if( z[0]=='-' ){
        z[0] = 0;
        break;
      }
      if( z[0]!='.' ) continue;
      if ( d<3 ){
        z[0] = ',';
        d++;
      }else{
        z[0] = '\0';
        break;
      }
    }
    printf("#define RELEASE_RESOURCE_VERSION %s", vx);
    while( d<3 ){ printf(",0"); d++; }
    printf("\n");
#if defined(__clang__) && defined(__clang_major__)
    printf("#define COMPILER \"clang-" 
                    CTIMEOPT_VAL(__clang_major__) "."
                    CTIMEOPT_VAL(__clang_minor__) "."
                    CTIMEOPT_VAL(__clang_patchlevel__) "\"\n");
#elif defined(__GNUC__) && defined(__VERSION__)
    printf("#define COMPILER \"gcc-" __VERSION__ "\"\n");
#else
    printf("#define COMPILER \"unknown\"\n");
#endif
    return 0;
}
