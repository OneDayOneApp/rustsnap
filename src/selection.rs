//! Screen-region selection geometry, independent of AppKit.
//! Coordinates use a top-left origin in local logical screen points.
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SelectionRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}
#[derive(Clone, Copy, Debug, Default, PartialEq)]
struct Point {
    x: f64,
    y: f64,
}
#[derive(Clone, Copy, Debug)]
enum Gesture {
    Create {
        anchor: Point,
    },
    Move {
        start: Point,
        rect: SelectionRect,
    },
    Resize {
        anchor: Point,
        horizontal: bool,
        vertical: bool,
        fixed: SelectionRect,
    },
}
#[derive(Default)]
pub struct Selection {
    size: Point,
    rect: SelectionRect,
    gesture: Option<Gesture>,
}
impl SelectionRect {
    fn between(a: Point, b: Point) -> Self {
        Self {
            x: a.x.min(b.x),
            y: a.y.min(b.y),
            width: (a.x - b.x).abs(),
            height: (a.y - b.y).abs(),
        }
    }
    fn valid(self) -> bool {
        self.width > 3. && self.height > 3.
    }
    fn handles(self) -> [Point; 8] {
        let x = self.x;
        let y = self.y;
        let r = x + self.width;
        let b = y + self.height;
        let mx = (x + r) / 2.;
        let my = (y + b) / 2.;
        [
            Point { x, y },
            Point { x: mx, y },
            Point { x: r, y },
            Point { x: r, y: my },
            Point { x: r, y: b },
            Point { x: mx, y: b },
            Point { x, y: b },
            Point { x, y: my },
        ]
    }
}
impl Selection {
    pub fn reset(&mut self, w: f64, h: f64) {
        self.size = Point {
            x: finite(w).max(0.),
            y: finite(h).max(0.),
        };
        self.clear();
    }
    pub fn clear(&mut self) {
        self.rect = SelectionRect::default();
        self.gesture = None;
    }
    fn clamp(&self, p: Point) -> Point {
        Point {
            x: finite(p.x).clamp(0., self.size.x),
            y: finite(p.y).clamp(0., self.size.y),
        }
    }
    /// -1 outside, 0 inside; 1..8 = NW,N,NE,E,SE,S,SW,W. Handle hit radius is 6 pt.
    fn hit(&self, p: Point) -> i32 {
        if !self.rect.valid() {
            return -1;
        }
        for (i, h) in self.rect.handles().iter().enumerate() {
            if (p.x - h.x).abs() <= 6. && (p.y - h.y).abs() <= 6. {
                return i as i32 + 1;
            }
        }
        if p.x >= self.rect.x
            && p.x <= self.rect.x + self.rect.width
            && p.y >= self.rect.y
            && p.y <= self.rect.y + self.rect.height
        {
            0
        } else {
            -1
        }
    }
    fn down(&mut self, p: Point) {
        let hit = self.hit(p);
        let p = self.clamp(p);
        self.gesture = Some(match hit {
            0 => Gesture::Move {
                start: p,
                rect: self.rect,
            },
            1..=8 => {
                let r = self.rect;
                let index = hit as usize - 1;
                let opposite = [4, 5, 6, 7, 0, 1, 2, 3][index];
                Gesture::Resize {
                    anchor: r.handles()[opposite],
                    horizontal: ![2, 6].contains(&hit),
                    vertical: ![4, 8].contains(&hit),
                    fixed: r,
                }
            }
            _ => {
                self.rect = SelectionRect {
                    x: p.x,
                    y: p.y,
                    width: 0.,
                    height: 0.,
                };
                Gesture::Create { anchor: p }
            }
        });
    }
    fn drag(&mut self, p: Point) {
        self.drag_constrained(p, false);
    }
    fn drag_constrained(&mut self, p: Point, lock_aspect: bool) {
        let p = self.clamp(p);
        if let Some(g) = self.gesture {
            self.rect = match g {
                Gesture::Create { anchor } => {
                    if lock_aspect {
                        self.corner_aspect(anchor, p, 1.)
                    } else {
                        SelectionRect::between(anchor, p)
                    }
                }
                Gesture::Move { start, rect } => SelectionRect {
                    x: (rect.x + p.x - start.x).clamp(0., (self.size.x - rect.width).max(0.)),
                    y: (rect.y + p.y - start.y).clamp(0., (self.size.y - rect.height).max(0.)),
                    ..rect
                },
                Gesture::Resize {
                    anchor,
                    horizontal,
                    vertical,
                    fixed,
                } => {
                    if lock_aspect && fixed.width > 0. && fixed.height > 0. {
                        let ratio = fixed.width / fixed.height;
                        if horizontal && vertical {
                            self.corner_aspect(anchor, p, ratio)
                        } else if horizontal {
                            // E/W handles preserve the opposite edge midpoint.
                            let sign = if p.x < anchor.x { -1. } else { 1. };
                            let available_x = if sign < 0. {
                                anchor.x
                            } else {
                                self.size.x - anchor.x
                            };
                            let max_height = 2. * anchor.y.min(self.size.y - anchor.y);
                            let width = (p.x - anchor.x)
                                .abs()
                                .min(available_x)
                                .min(max_height * ratio);
                            let height = width / ratio;
                            SelectionRect {
                                x: anchor.x.min(anchor.x + sign * width),
                                y: anchor.y - height / 2.,
                                width,
                                height,
                            }
                        } else {
                            // N/S handles preserve the opposite edge midpoint.
                            let sign = if p.y < anchor.y { -1. } else { 1. };
                            let available_y = if sign < 0. {
                                anchor.y
                            } else {
                                self.size.y - anchor.y
                            };
                            let max_width = 2. * anchor.x.min(self.size.x - anchor.x);
                            let height = (p.y - anchor.y)
                                .abs()
                                .min(available_y)
                                .min(max_width / ratio);
                            let width = height * ratio;
                            SelectionRect {
                                x: anchor.x - width / 2.,
                                y: anchor.y.min(anchor.y + sign * height),
                                width,
                                height,
                            }
                        }
                    } else {
                        let mut r = SelectionRect::between(anchor, p);
                        if !horizontal {
                            r.x = fixed.x;
                            r.width = fixed.width;
                        }
                        if !vertical {
                            r.y = fixed.y;
                            r.height = fixed.height;
                        }
                        r
                    }
                }
            };
        }
    }
    fn corner_aspect(&self, anchor: Point, p: Point, ratio: f64) -> SelectionRect {
        let sx = if p.x < anchor.x { -1. } else { 1. };
        let sy = if p.y < anchor.y { -1. } else { 1. };
        let max_width = if sx < 0. {
            anchor.x
        } else {
            self.size.x - anchor.x
        };
        let max_height = if sy < 0. {
            anchor.y
        } else {
            self.size.y - anchor.y
        };
        let width = (p.x - anchor.x)
            .abs()
            .max((p.y - anchor.y).abs() * ratio)
            .min(max_width)
            .min(max_height * ratio);
        SelectionRect::between(
            anchor,
            Point {
                x: anchor.x + sx * width,
                y: anchor.y + sy * width / ratio,
            },
        )
    }
    fn nudge(&mut self, dx: f64, dy: f64) {
        if self.gesture.is_none() && self.rect.valid() {
            self.rect.x =
                (self.rect.x + finite(dx)).clamp(0., (self.size.x - self.rect.width).max(0.));
            self.rect.y =
                (self.rect.y + finite(dy)).clamp(0., (self.size.y - self.rect.height).max(0.));
        }
    }
    fn up(&mut self) {
        self.gesture = None;
    }
}
fn finite(v: f64) -> f64 {
    if v.is_finite() {
        v
    } else {
        0.
    }
}
#[no_mangle]
pub extern "C" fn rust_selection_new() -> *mut Selection {
    Box::into_raw(Box::new(Selection::default()))
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_free(s: *mut Selection) {
    if !s.is_null() {
        drop(Box::from_raw(s));
    }
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_reset(s: *mut Selection, w: f64, h: f64) {
    (*s).reset(w, h);
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_rect(s: *const Selection) -> SelectionRect {
    (*s).rect
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_valid(s: *const Selection) -> bool {
    (*s).rect.valid()
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_down(s: *mut Selection, x: f64, y: f64) {
    (*s).down(Point { x, y });
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_drag(s: *mut Selection, x: f64, y: f64) {
    (*s).drag(Point { x, y });
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_drag_constrained(
    s: *mut Selection,
    x: f64,
    y: f64,
    lock_aspect: bool,
) {
    (*s).drag_constrained(Point { x, y }, lock_aspect);
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_nudge(s: *mut Selection, dx: f64, dy: f64) {
    (*s).nudge(dx, dy);
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_up(s: *mut Selection) {
    (*s).up();
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_clear(s: *mut Selection) {
    (*s).clear();
}
#[no_mangle]
pub unsafe extern "C" fn rust_selection_hit(s: *const Selection, x: f64, y: f64) -> i32 {
    (*s).hit(Point { x, y })
}
#[cfg(test)]
mod tests {
    use super::*;
    fn selection() -> Selection {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: 100., y: 100. });
        s.drag(Point { x: 300., y: 300. });
        s.up();
        s
    }
    #[test]
    fn reversed_drag() {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: 300., y: 300. });
        s.drag(Point { x: 100., y: 100. });
        s.up();
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 200.,
                height: 200.
            }
        );
    }
    #[test]
    fn screen_bounds() {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: -100., y: -100. });
        s.drag(Point { x: 900., y: 700. });
        s.up();
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 0.,
                y: 0.,
                width: 800.,
                height: 600.
            }
        );
    }
    #[test]
    fn move_clamped() {
        let mut s = selection();
        s.down(Point { x: 200., y: 200. });
        s.drag(Point { x: 800., y: 600. });
        s.up();
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 600.,
                y: 400.,
                width: 200.,
                height: 200.
            }
        );
        s.down(Point { x: 700., y: 500. });
        s.drag(Point { x: 0., y: 0. });
        s.up();
        assert_eq!(s.rect.x, 0.);
        assert_eq!(s.rect.y, 0.);
    }
    #[test]
    fn eight_handles() {
        let s = selection();
        for (i, p) in s.rect.handles().iter().enumerate() {
            assert_eq!(s.hit(*p), i as i32 + 1);
        }
        assert_eq!(s.hit(Point { x: 200., y: 200. }), 0);
        assert_eq!(s.hit(Point { x: 0., y: 0. }), -1);
        assert_eq!(s.hit(Point { x: 94., y: 100. }), 1);
        assert_eq!(s.hit(Point { x: 93., y: 100. }), -1);
    }
    #[test]
    fn all_eight_resize() {
        let initial = selection();
        let expected = [
            SelectionRect {
                x: 80.,
                y: 80.,
                width: 220.,
                height: 220.,
            },
            SelectionRect {
                x: 100.,
                y: 80.,
                width: 200.,
                height: 220.,
            },
            SelectionRect {
                x: 100.,
                y: 80.,
                width: 180.,
                height: 220.,
            },
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 180.,
                height: 200.,
            },
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 180.,
                height: 180.,
            },
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 200.,
                height: 180.,
            },
            SelectionRect {
                x: 80.,
                y: 100.,
                width: 220.,
                height: 180.,
            },
            SelectionRect {
                x: 80.,
                y: 100.,
                width: 220.,
                height: 200.,
            },
        ];
        for (i, p) in initial.rect.handles().iter().enumerate() {
            let mut s = selection();
            s.down(*p);
            s.drag(Point {
                x: p.x - 20.,
                y: p.y - 20.,
            });
            s.up();
            assert_eq!(s.rect, expected[i], "handle {}", i + 1);
        }
    }
    #[test]
    fn zero_area() {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: 50., y: 50. });
        s.up();
        assert!(!s.rect.valid());
        s.down(Point { x: 50., y: 50. });
        s.drag(Point { x: 100., y: 50. });
        s.up();
        assert!(!s.rect.valid());
    }
    #[test]
    fn crossing_anchors() {
        let mut s = selection();
        s.down(Point { x: 100., y: 100. });
        s.drag(Point { x: 400., y: 450. });
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 300.,
                y: 300.,
                width: 100.,
                height: 150.
            }
        );
        s.drag(Point { x: 50., y: 60. });
        s.up();
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 50.,
                y: 60.,
                width: 250.,
                height: 240.
            }
        );
    }
    #[test]
    fn clear_and_release() {
        let mut s = selection();
        s.clear();
        assert!(!s.rect.valid());
        assert_eq!(s.hit(Point { x: 0., y: 0. }), -1);
        s.down(Point { x: 10., y: 10. });
        s.drag(Point { x: 20., y: 20. });
        s.up();
        let r = s.rect;
        s.drag(Point { x: 40., y: 40. });
        assert_eq!(s.rect, r);
    }
    #[test]
    fn shift_create_square_and_boundary() {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: 700., y: 500. });
        s.drag_constrained(Point { x: 790., y: 550. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 700.,
                y: 500.,
                width: 90.,
                height: 90.
            }
        );
        s.drag_constrained(Point { x: 800., y: 600. }, true);
        assert_eq!(s.rect.width, 100.);
        assert_eq!(s.rect.height, 100.);
        s.up();
        s.clear();
        s.down(Point { x: 200., y: 300. });
        s.drag_constrained(Point { x: 50., y: 250. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 50.,
                y: 150.,
                width: 150.,
                height: 150.
            }
        );
    }
    fn wide_selection() -> Selection {
        let mut s = Selection::default();
        s.reset(800., 600.);
        s.down(Point { x: 100., y: 100. });
        s.drag(Point { x: 500., y: 300. });
        s.up();
        s
    }
    #[test]
    fn aspect_corner_resize_uses_gesture_start_ratio() {
        let mut s = wide_selection();
        s.down(Point { x: 500., y: 300. });
        s.drag_constrained(Point { x: 700., y: 350. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 600.,
                height: 300.
            }
        );
        s.drag_constrained(Point { x: 700., y: 500. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 100.,
                y: 100.,
                width: 700.,
                height: 350.
            }
        );
        s.drag(Point { x: 600., y: 200. });
        assert_eq!(s.rect.height, 100.);
        s.drag_constrained(Point { x: 600., y: 200. }, true);
        assert_eq!(s.rect.width / s.rect.height, 2.);
    }
    #[test]
    fn aspect_edge_resizes_keep_anchor_and_screen_bounds() {
        let mut s = wide_selection();
        s.down(Point { x: 500., y: 200. });
        s.drag_constrained(Point { x: 800., y: 500. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 100.,
                y: 25.,
                width: 700.,
                height: 350.
            }
        );
        s.up();
        let mut s = wide_selection();
        s.down(Point { x: 300., y: 100. });
        s.drag_constrained(Point { x: 800., y: 0. }, true);
        assert_eq!(
            s.rect,
            SelectionRect {
                x: 0.,
                y: 0.,
                width: 600.,
                height: 300.
            }
        );
    }
    #[test]
    fn nudge_bounds_and_active_gesture() {
        let mut s = selection();
        s.nudge(1., -1.);
        assert_eq!(s.rect.x, 101.);
        assert_eq!(s.rect.y, 99.);
        s.nudge(10000., 10000.);
        assert_eq!(s.rect.x, 600.);
        assert_eq!(s.rect.y, 400.);
        s.nudge(-10000., -10000.);
        assert_eq!(s.rect.x, 0.);
        assert_eq!(s.rect.y, 0.);
        s.down(Point { x: 100., y: 100. });
        let r = s.rect;
        s.nudge(20., 20.);
        assert_eq!(s.rect, r);
        s.clear();
        s.nudge(10., 10.);
        assert_eq!(s.rect, SelectionRect::default());
    }
}
