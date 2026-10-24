#include <stdbool.h>
#include <stddef.h>
typedef struct { double x,y; } RPoint;
typedef struct { double x,y,width,height; } RRect;
typedef struct { double r,g,b,a; } RColor;
typedef struct { int tool; RColor color; double width; RRect bounds; const RPoint*points; size_t count; const char *text; } RShape;
extern void *rust_model_new(void);
extern void rust_model_free(void*);
extern void rust_model_reset(void*,double,double);
extern int rust_model_tool(void*);
extern void rust_model_set_tool(void*,int);
extern void rust_model_set_width(void*,double);
extern void rust_model_set_color(void*,RColor);
extern void rust_model_begin(void*,double,double);
extern void rust_model_drag(void*,double,double);
extern void rust_model_text(void*,const char*);
extern void rust_model_finish(void*);
extern void rust_model_cancel(void*);
extern void rust_model_undo(void*);
extern void rust_model_redo(void*);
extern size_t rust_model_count(void*,bool);
extern RShape rust_model_shape(void*,size_t);
extern void rust_arrow(double,double,double,double,double,double*);

extern void rust_model_reframe(void*,double,double,double,double);
