//! Platform-independent annotation document and interaction state machine.
use std::ffi::{c_char, CStr, CString};
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}
impl Rect {
    fn between(a: Point, b: Point) -> Self {
        Self {
            x: a.x.min(b.x),
            y: a.y.min(b.y),
            width: (a.x - b.x).abs(),
            height: (a.y - b.y).abs(),
        }
    }
}
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Color {
    pub r: f64,
    pub g: f64,
    pub b: f64,
    pub a: f64,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Tool {
    Rectangle,
    Ellipse,
    Arrow,
    Pen,
    Text,
    Eraser,
    Mosaic,
}
impl Tool {
    fn from_id(id: i32) -> Option<Self> {
        match id {
            0 => Some(Self::Rectangle),
            1 => Some(Self::Ellipse),
            2 => Some(Self::Arrow),
            3 => Some(Self::Pen),
            4 => Some(Self::Text),
            5 => Some(Self::Eraser),
            6 => Some(Self::Mosaic),
            _ => None,
        }
    }
    fn id(self) -> i32 {
        self as i32
    }
}
#[derive(Clone, Debug)]
pub struct Annotation {
    pub tool: Tool,
    pub color: Color,
    pub width: f64,
    pub points: Vec<Point>,
    pub text: CString,
}
impl Annotation {
    fn bounds(&self) -> Rect {
        match (self.points.first(), self.points.last()) {
            (Some(a), Some(b)) => Rect::between(*a, *b),
            _ => Rect::default(),
        }
    }
}
pub struct Document {
    pub marks: Vec<Annotation>,
    pub undone: Vec<Annotation>,
    pub active: Option<Annotation>,
    pub tool: Tool,
    pub color: Color,
    pub width: f64,
    pub size: Point,
}
impl Default for Document {
    fn default() -> Self {
        Self {
            marks: vec![],
            undone: vec![],
            active: None,
            tool: Tool::Rectangle,
            color: Color {
                r: 1.,
                g: 0.2,
                b: 0.2,
                a: 1.,
            },
            width: 3.,
            size: Point::default(),
        }
    }
}
impl Document {
    pub fn reset(&mut self, w: f64, h: f64) {
        self.size = Point {
            x: w.max(0.),
            y: h.max(0.),
        };
        self.marks.clear();
        self.undone.clear();
        self.active = None;
    }
    fn clamp(&self, p: Point) -> Point {
        Point {
            x: if p.x.is_finite() {
                p.x.clamp(0., self.size.x)
            } else {
                0.
            },
            y: if p.y.is_finite() {
                p.y.clamp(0., self.size.y)
            } else {
                0.
            },
        }
    }
    pub fn begin(&mut self, p: Point) {
        if self.size.x <= 0. || self.size.y <= 0. {
            return;
        }
        self.active = Some(Annotation {
            tool: self.tool,
            color: self.color,
            width: self.width,
            points: vec![self.clamp(p)],
            text: CString::default(),
        });
    }
    pub fn drag(&mut self, p: Point) {
        let p = self.clamp(p);
        if let Some(a) = self.active.as_mut() {
            if a.tool == Tool::Text {
                return;
            }
            if !matches!(a.tool, Tool::Pen | Tool::Eraser | Tool::Mosaic) && a.points.len() > 1 {
                a.points.pop();
            }
            if a.points.last() != Some(&p) {
                a.points.push(p);
            }
        }
    }
    pub fn text(&mut self, text: &str) {
        if let Some(a) = self.active.as_mut() {
            if a.tool == Tool::Text {
                a.text = CString::new(text.replace('\0', "")).unwrap();
            }
        }
    }
    pub fn finish(&mut self) {
        if let Some(a) = self.active.take() {
            let valid = if a.tool == Tool::Text {
                !a.text.as_bytes().is_empty()
            } else {
                matches!(a.tool, Tool::Pen | Tool::Eraser | Tool::Mosaic) || (a.points.len() > 1 && a.points.first() != a.points.last())
            };
            if valid {
                self.marks.push(a);
                self.undone.clear();
            }
        }
    }
    pub fn undo(&mut self) {
        self.active = None;
        if let Some(a) = self.marks.pop() {
            self.undone.push(a);
        }
    }
    pub fn redo(&mut self) {
        self.active = None;
        if let Some(a) = self.undone.pop() {
            self.marks.push(a);
        }
    }
    pub fn set_tool(&mut self, id: i32) {
        if let Some(t) = Tool::from_id(id) {
            self.active = None;
            self.tool = t;
        }
    }
    pub fn set_width(&mut self, w: f64) {
        if w.is_finite() {
            self.width = w.clamp(1., 64.);
        }
    }
    pub fn set_color(&mut self, c: Color) {
        fn unit(v: f64) -> f64 {
            if v.is_finite() {
                v.clamp(0., 1.)
            } else {
                0.
            }
        }
        self.color = Color {
            r: unit(c.r),
            g: unit(c.g),
            b: unit(c.b),
            a: unit(c.a),
        };
    }
}
pub fn arrow(a: Point, b: Point, width: f64) -> [Point; 3] {
    let angle = (b.y - a.y).atan2(b.x - a.x);
    let n = (width * 4.).max(12.);
    [
        Point {
            x: b.x - n * (angle - 0.5).cos(),
            y: b.y - n * (angle - 0.5).sin(),
        },
        b,
        Point {
            x: b.x - n * (angle + 0.5).cos(),
            y: b.y - n * (angle + 0.5).sin(),
        },
    ]
}
#[repr(C)]
pub struct Snapshot {
    pub tool: i32,
    pub color: Color,
    pub width: f64,
    pub bounds: Rect,
    pub points: *const Point,
    pub count: usize,
    pub text: *const c_char,
}
impl Snapshot {
    fn empty() -> Self {
        Self {
            tool: -1,
            color: Color {
                r: 0.,
                g: 0.,
                b: 0.,
                a: 0.,
            },
            width: 0.,
            bounds: Rect::default(),
            points: std::ptr::null(),
            count: 0,
            text: std::ptr::null(),
        }
    }
}
// FFI calls occur only on AppKit's main thread. Snapshot pointers remain valid until mutation.
#[no_mangle]
pub extern "C" fn rust_model_new() -> *mut Document {
    Box::into_raw(Box::new(Document::default()))
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_free(d: *mut Document) {
    if !d.is_null() {
        drop(Box::from_raw(d));
    }
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_reset(d: *mut Document, w: f64, h: f64) {
    (*d).reset(w, h);
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_reframe(d: *mut Document, w: f64, h: f64, dx: f64, dy: f64) {
    let d = &mut *d;
    if !(w.is_finite() && h.is_finite() && dx.is_finite() && dy.is_finite()) {
        return;
    }
    d.size = Point {
        x: w.max(0.),
        y: h.max(0.),
    };
    for mark in d
        .marks
        .iter_mut()
        .chain(d.undone.iter_mut())
        .chain(d.active.iter_mut())
    {
        for p in &mut mark.points {
            p.x += dx;
            p.y += dy;
        }
    }
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_tool(d: *mut Document) -> i32 {
    (*d).tool.id()
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_set_tool(d: *mut Document, t: i32) {
    (*d).set_tool(t);
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_set_width(d: *mut Document, w: f64) {
    (*d).set_width(w);
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_set_color(d: *mut Document, c: Color) {
    (*d).set_color(c);
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_begin(d: *mut Document, x: f64, y: f64) {
    (*d).begin(Point { x, y });
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_drag(d: *mut Document, x: f64, y: f64) {
    (*d).drag(Point { x, y });
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_text(d: *mut Document, s: *const c_char) {
    if !s.is_null() {
        (*d).text(&CStr::from_ptr(s).to_string_lossy());
    }
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_finish(d: *mut Document) {
    (*d).finish();
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_cancel(d: *mut Document) {
    (*d).active = None;
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_undo(d: *mut Document) {
    (*d).undo();
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_redo(d: *mut Document) {
    (*d).redo();
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_count(d: *mut Document, active: bool) -> usize {
    (*d).marks.len() + usize::from(active && (*d).active.is_some())
}
#[no_mangle]
pub unsafe extern "C" fn rust_model_shape(d: *mut Document, index: usize) -> Snapshot {
    let d = &*d;
    let a = d.marks.get(index).or_else(|| {
        if index == d.marks.len() {
            d.active.as_ref()
        } else {
            None
        }
    });
    match a {
        Some(a) => Snapshot {
            tool: a.tool.id(),
            color: a.color,
            width: a.width,
            bounds: a.bounds(),
            points: a.points.as_ptr(),
            count: a.points.len(),
            text: a.text.as_ptr(),
        },
        None => Snapshot::empty(),
    }
}
#[no_mangle]
pub unsafe extern "C" fn rust_arrow(ax: f64, ay: f64, bx: f64, by: f64, w: f64, out: *mut f64) {
    for (i, p) in arrow(Point { x: ax, y: ay }, Point { x: bx, y: by }, w)
        .iter()
        .enumerate()
    {
        *out.add(i * 2) = p.x;
        *out.add(i * 2 + 1) = p.y;
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn doc() -> Document {
        let mut d = Document::default();
        d.reset(800., 500.);
        d
    }
    fn gesture(d: &mut Document) {
        d.begin(Point { x: 10., y: 20. });
        d.drag(Point { x: 80., y: 90. });
        d.finish();
    }
    #[test]
    fn five_tools() {
        let mut d = doc();
        for t in 0..5 {
            d.set_tool(t);
            if t == 4 {
                d.begin(Point { x: 10., y: 20. });
                d.text("hello");
                d.finish();
            } else {
                gesture(&mut d);
            }
        }
        assert_eq!(d.marks.len(), 5);
        assert_eq!(d.marks[4].text.to_str().unwrap(), "hello");
    }
    #[test]
    fn undo_redo_and_branch() {
        let mut d = doc();
        gesture(&mut d);
        d.set_tool(2);
        gesture(&mut d);
        d.undo();
        assert_eq!(d.marks.len(), 1);
        d.redo();
        assert_eq!(d.marks[1].tool, Tool::Arrow);
        d.undo();
        gesture(&mut d);
        assert!(d.undone.is_empty());
        for _ in 0..4 {
            d.undo();
        }
        for _ in 0..4 {
            d.redo();
        }
        assert_eq!(d.marks.len(), 2);
    }
    #[test]
    fn rectangle_normalizes_and_clamps() {
        let mut d = doc();
        d.begin(Point { x: 900., y: 700. });
        d.drag(Point { x: -10., y: 30. });
        d.finish();
        assert_eq!(
            d.marks[0].bounds(),
            Rect {
                x: 0.,
                y: 30.,
                width: 800.,
                height: 470.
            }
        );
    }
    #[test]
    fn pen_dot_and_loop_are_valid_and_undoable() {
        let mut d = doc();
        d.set_tool(3);
        d.begin(Point { x: 40., y: 40. });
        d.finish();
        assert_eq!(d.marks.len(), 1);
        assert_eq!(d.marks[0].points.len(), 1);
        d.undo();
        assert!(d.marks.is_empty());
        d.redo();
        d.begin(Point { x: 10., y: 10. });
        d.drag(Point { x: 20., y: 20. });
        d.drag(Point { x: 10., y: 10. });
        d.finish();
        assert_eq!(d.marks.len(), 2);
        assert_eq!(d.marks[1].points.len(), 3);
    }
    #[test]
    fn eraser_retains_path_and_participates_in_history() {
        let mut d = doc();
        d.set_tool(5);
        d.begin(Point { x: 10., y: 10. });
        d.drag(Point { x: 30., y: 40. });
        d.drag(Point { x: 60., y: 70. });
        d.finish();
        assert_eq!(d.marks[0].tool, Tool::Eraser);
        assert_eq!(d.marks[0].points.len(), 3);
        d.undo();assert!(d.marks.is_empty());
        d.redo();assert_eq!(d.marks.len(), 1);
        d.begin(Point { x: 20., y: 20. });d.finish();
        assert_eq!(d.marks[1].points.len(), 1);
    }
    #[test]
    fn mosaic_retains_stroke_and_single_click() {
        let mut d = doc();d.set_tool(6);
        d.begin(Point { x: 10., y: 10. });d.drag(Point { x: 20., y: 20. });d.drag(Point { x: 40., y: 10. });d.finish();
        assert_eq!(d.marks[0].tool, Tool::Mosaic);assert_eq!(d.marks[0].points.len(), 3);
        d.begin(Point { x: 50., y: 50. });d.finish();assert_eq!(d.marks.len(), 2);
        d.undo();d.redo();assert_eq!(d.marks.len(), 2);
    }
    #[test]
    fn pen_retains_intermediate_points() {
        let mut d = doc();
        d.set_tool(3);
        d.begin(Point { x: 10., y: 20. });
        d.drag(Point { x: 30., y: 40. });
        d.drag(Point { x: 50., y: 60. });
        d.finish();
        assert_eq!(d.marks[0].points.len(), 3);
    }
    #[test]
    fn shapes_keep_only_endpoints() {
        let mut d = doc();
        d.begin(Point { x: 10., y: 20. });
        d.drag(Point { x: 30., y: 40. });
        d.drag(Point { x: 50., y: 60. });
        d.finish();
        assert_eq!(d.marks[0].points.len(), 2);
    }
    #[test]
    fn cancelled_or_empty_gestures_do_not_commit() {
        let mut d = doc();
        d.begin(Point { x: 10., y: 20. });
        d.finish();
        d.set_tool(4);
        d.begin(Point { x: 10., y: 20. });
        d.finish();
        assert!(d.marks.is_empty());
    }
    #[test]
    fn style_snapshots_and_bounds() {
        let mut d = doc();
        d.set_width(100.);
        d.set_color(Color {
            r: 2.,
            g: -1.,
            b: 0.3,
            a: 1.,
        });
        gesture(&mut d);
        d.set_width(1.);
        assert_eq!(d.marks[0].width, 64.);
        assert_eq!(d.marks[0].color.r, 1.);
        assert_eq!(d.marks[0].color.g, 0.);
    }
    #[test]
    fn arrow_points_backwards() {
        let p = arrow(Point { x: 0., y: 0. }, Point { x: 100., y: 0. }, 3.);
        assert!(p[0].x < 100. && p[0].y > 0. && p[2].y < 0.);
    }
    #[test]
    fn reframe_keeps_history_and_offsets_without_losing_styles() {
        let mut d = doc();
        gesture(&mut d);
        d.undo();
        unsafe {
            rust_model_reframe(&mut d, 400., 300., -5., 8.);
        }
        assert_eq!(d.size, Point { x: 400., y: 300. });
        d.redo();
        assert_eq!(d.marks[0].points[0], Point { x: 5., y: 28. });
        assert_eq!(d.marks[0].width, 3.);
    }
    #[test]
    fn reset_clears_history() {
        let mut d = doc();
        gesture(&mut d);
        d.undo();
        d.reset(100., 200.);
        assert!(d.marks.is_empty() && d.undone.is_empty() && d.active.is_none());
    }
}
