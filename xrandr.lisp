(uiop:define-package :fare-scripts/xrandr
  (:use :cl :uiop :fare-utils
        :optima :optima.ppcre
        :inferior-shell :cl-scripting :cl-launch/dispatch)
  (:export #:screen-device-up #:screen-device-right #:screen-device-down #:screen-device-left))

(in-package :fare-scripts/xrandr)

;; TODO: write a real parser for xrandr output?

(defun current-device () "eDP1")

(defun xinput-device-properties (device-id)
  (loop :for line :in (cdr (run/lines `(xinput list-props ,device-id))) :collect
    (match line
      ((ppcre "^\\s+([A-Za-z-0-9][A-Za-z0-9 ]*[A-Za-z-0-9]) [(]([0-9]+)[)]:\\s+(.*)$"
              name id value)
       (list name (parse-integer id) value))
      (_ (error "Cannot parse device property line ~A" line)))))

(defun touchscreen-device ()
  (dolist (line (run/lines '(xinput list)))
    (match line
      ((ppcre "(ELAN21EF:00 04F3:[0-9A-F]{4})\\s+id\=([0-9]{1,2})\\s+" _ x)
       (return (values (parse-integer x)))))))

(defun configure-touchscreen (&key invert-x invert-y swap-xy)
  (nest
   (if-let (ts (touchscreen-device)))
   (if-let (properties (ignore-errors (xinput-device-properties ts))))
   (flet ((property-id (name) (second (find name properties :key 'first :test 'equal)))))
   (if-let (axis-inversion (property-id "Evdev Axis Inversion")))
   (if-let (axes-swap (property-id "Evdev Axes Swap")))
   (progn
     (run/i `(xinput set-prop ,ts ,axis-inversion ,(if invert-x 1 0) ,(if invert-y 1 0)))
     (run/i `(xinput set-prop ,ts ,axes-swap ,(if swap-xy 1 0))))))

(exporting-definitions

(defun screen-device-up (&optional (device (current-device)))
  (run/i `(xrandr --output ,device --rotate normal))
  (configure-touchscreen :invert-x nil :invert-y nil :swap-xy nil))
(defun screen-device-right (&optional (device (current-device)))
  (run/i `(xrandr --output ,device --rotate right))
  (configure-touchscreen :invert-x nil :invert-y t :swap-xy t))
(defun screen-device-down (&optional (device (current-device)))
  (run/i `(xrandr --output ,device --rotate inverted))
  (configure-touchscreen :invert-x t :invert-y t :swap-xy nil))
(defun screen-device-left (&optional (device (current-device)))
  (run/i `(xrandr --output ,device --rotate left))
  (configure-touchscreen :invert-x t :invert-y nil :swap-xy t))

);exporting-definitions

;; Not all our exported symbols are worth exposing to the shell command-line.
(register-commands :fare-scripts/xrandr)
