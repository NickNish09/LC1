;;
;; eval.lisp
;; Release: PVSio-6.0.9 (3/14/14)
;;
;; Contact: Cesar Munoz (cesar.a.munoz@nasa.gov)
;; NASA Langley Research Center
;; http://shemesh.larc.nasa.gov/people/cam/PVSio
;;
;; Copyright (c) 2011-2012 United States Government as represented by
;; the National Aeronautics and Space Administration.  No copyright
;; is claimed in the United States under Title 17, U.S.Code. All Other
;; Rights Reserved.
;;
;; List of strategies in PVSio: eval, eval-expr, and eval-formula
;;

(in-package :pvs)

(defparameter *pvsio-strategies* nil)

(pushnew "eval-formula" *pvsio-strategies* :test #'string=)
(pushnew "eval-expr"    *pvsio-strategies* :test #'string=)
(pushnew "eval"         *pvsio-strategies* :test #'string=)

(defun evalexpr (expr &optional safe)
  (when expr
    (catch '*eval-error*
      (catch '*pvsio-inprover*
	(catch 'tcerror
	  (let* ((pr-input (extra-get-expr expr))
		 (*tccforms* nil)
		 (*generate-tccs* 'all)
		 (tc-input (pc-typecheck pr-input)))
	    (when (and *tccforms* safe)
	      (format t "~%Typechecking ~s produced TCCs:~%" expr)
	      (evaluator-print-tccs *tccforms*)
	      (throw '*eval-error* 
		     (format nil 
			     "Use option :safe? nil if TCCs are provable")))
	    (let ((cl-input (pvs2cl tc-input)))
	      (multiple-value-bind 
		  (cl-eval err)
		  (catch 'undefined (ignore-errors (eval cl-input)))
		(cond (err 
		       (throw '*eval-error* (format nil "~a" err)))
		      ((and (null err) (eq cl-eval 'cant-translate))
		       (throw '*eval-error* (format nil "Expression doesn't appear to be ground")))
		      (t 
		       (multiple-value-bind 
			   (pvs-val err)
			   (ignore-errors 
			     (cl2pvs cl-eval (type tc-input)))
			 (if (expr? pvs-val) pvs-val
			   (throw '*eval-error*
				  (format nil "Result ~a is not ground" cl-eval))))))))))))))

(defrule eval-expr (expr &optional safe? (auto? t) quiet?)
  (let ((e (extra-get-expr expr)))
    (when e
	(let ((result (evalexpr e safe?)))
	  (if (stringp result)
	      (unless quiet? (printf "Error: ~a~%" result))
	    (when result 
	      (let ((casexpr (format nil "~a = ~a" e result)))
		(with-fresh-labels
		 ((!evx))
		 (trust *PVSGroundEvaluator*
			(discriminate (case casexpr) !evx)
			((skip) !
			 (when auto? (eval-formula !evx)))))))))))
  "[PVSio] Adds the hypothesis expr=eval(EXPR) to the current goal, 
where eval(EXPR) is the ground evaluation of EXPR. If SAFE? is t and EXPR
generates TCCs, the expression is not evaluated. Otherwise, TCCs
are added as subgoals and the expression is evaluated. If AUTO? is t,
TCCs are ground evaluated. The strategy is sound in the sense that
user-defined semantic attachments are not evaluated. However, if SAFE? is nil,
the strategy may not terminate properly in the presence of unproven TCCs. When
QUIET? is t, the strategy fails silently."
  "Evaluating expression ~a in the current sequent")

(defrule eval-formula (&optional (fnum 1) safe? quiet?)
  (let ((fexpr (extra-get-seqf fnum)))
    (when fexpr
      (let ((expr   (formula fexpr))
	    (result (evalexpr expr safe?)))
	(if (stringp result)
	    (unless quiet? (printf "Error: ~a~%" result))
	  (when result 
	    (trust *PVSGroundEvaluator*
		   (case result)
		   (! (skip))))))))
  "[PVSio] Evaluates the formula FNUM in Common Lisp and adds the result to 
the antecedent of the current goal. If SAFE? is t and FNUM generates TCCs, 
the expression is not evaluated. The strategy is safe in the sense that 
user-defined semantic attachments are not evaluated. However, 
if SAFE? is nil, the strategy may not terminate properly in
the presence of unproven TCCs.  When QUIET? is t, the strategy fails silently"
  "Evaluating formula ~a in the current sequent")

(defrule eval (expr &optional safe? quiet?)
  (let ((e (extra-get-expr expr)))
    (when e
      (let ((*in-evaluator* t)
	    (result (evalexpr e safe?)))
	(if (stringp result)
	    (unless quiet? (printf "Error: ~a~%" result))
	  (when result
	    (printf "~a = ~a~%" e result))))))
  "[PVSio] Prints the evaluation of expression EXPR. If SAFE? is t and EXPR 
generates TCCs, the expression is not evaluated. This strategy evaluates
semantic attachments. Therefore, it may not terminate properly. When QUIET? 
is t, the strategy fails silently."
  "Printing the evaluation of ~a")

(defstrat pvsio-about ()
  (let ((version *pvsio-version*)
	(strategies *pvsio-strategies*))
    (printf "%--
% ~a 
% http://shemesh.larc.nasa.gov/people/cam/PVSio
% Strategies in PVSio: ~{~a~^, ~}
%--~%" version strategies))
  "[PVSio] Prints PVSio's about information.")

