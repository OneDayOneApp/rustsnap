#ifndef RUSTSNIP_SELECTION_H
#define RUSTSNIP_SELECTION_H
#include <stdbool.h>
typedef struct { double x,y,width,height; } SelectionRect;
// Opaque state. All calls must be serialized by the caller (AppKit main thread).
extern void *rust_selection_new(void);
extern void rust_selection_free(void *state);
extern void rust_selection_reset(void *state,double screen_width,double screen_height);
extern SelectionRect rust_selection_rect(const void *state);
// A rectangle is valid only when both dimensions exceed 3 logical points.
extern bool rust_selection_valid(const void *state);
extern void rust_selection_down(void *state,double x,double y);
extern void rust_selection_drag(void *state,double x,double y);
// Shift: create squares; resize preserves the ratio at gesture start. Move is unchanged.
extern void rust_selection_drag_constrained(void *state,double x,double y,bool lock_aspect);
// Move a valid rectangle by logical points, clamped to screen; ignored during a gesture.
extern void rust_selection_nudge(void *state,double dx,double dy);
extern void rust_selection_up(void *state);
extern void rust_selection_clear(void *state);
// -1 outside, 0 inside, 1 NW, 2 N, 3 NE, 4 E, 5 SE, 6 S, 7 SW, 8 W.
// Handles use a +/-6 point square hit target. Handle hits precede interior hits.
extern int rust_selection_hit(const void *state,double x,double y);
#endif
