;;; w3m.el --- an Emacs interface to w3m

;; Copyright (C) 2000, 2001, 2002, 2003, 2004
;; TSUCHIYA Masatoshi <tsuchiya@namazu.org>

;; Authors: TSUCHIYA Masatoshi <tsuchiya@namazu.org>,
;;          Shun-ichi GOTO     <gotoh@taiyo.co.jp>,
;;          Satoru Takabayashi <satoru-t@is.aist-nara.ac.jp>,
;;          Hideyuki SHIRAI    <shirai@meadowy.org>,
;;          Keisuke Nishida    <kxn30@po.cwru.edu>,
;;          Yuuichi Teranishi  <teranisi@gohome.org>,
;;          Akihiro Arisawa    <ari@mbf.sphere.ne.jp>,
;;          Katsumi Yamaoka    <yamaoka@jpl.org>
;; Keywords: w3m, WWW, hypermedia

;; This file is the main part of emacs-w3m.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 59 Temple Place, Suite 330; Boston, MA 02111-1307, USA.


;;; Commentary:

;; Emacs-w3m is an Emacs interface to the w3m program.  For more
;; detail about w3m, see:
;;
;;    http://w3m.sourceforge.net/


;;; How to install:

;; See the README file in any case.  We also recommend you check
;; whether a newer version of w3m is released.
;;
;; The outline of installation is: run the `configure' script and type
;; `make install' in the top directory of the emacs-w3m distribution.


;;; Code:

;; Developers, you must not use the cl functions (e.g., `butlast',
;; `coerce', `merge', etc.) in any emacs-w3m or shimbun modules.  To
;; exclude run-time cl is the policy of emacs-w3m.  However, XEmacs
;; employs the cl package for all time, or those functions are
;; possibly provided in the other modules like APEL, so you may use
;; them only in w3m-xmas.el or w3m-om.el.
(eval-when-compile
  (require 'cl))

(eval-when-compile
  (unless (dolist (var nil t))
    ;; Override the `dolist' macro which may be faultily provided by
    ;; old egg.el.
    (load "cl-macs" nil t)))

;; The following variables will be referred to by the external modules
;; which bind such variables only when compiling themselves.  And also
;; some modules have the `defadvice' forms including them and run
;; `byte-compile' at run-time.
(eval-and-compile
  (defvar w3m-current-title nil
    "Title of a page visiting in the current buffer.")
  (defvar w3m-current-url nil
    "A url of a page visiting in the current buffer."))

(require 'w3m-util)
(require 'w3m-proc)

;; Silence the Emacs' byte-compiler that says ``might not be defined''.
(eval-when-compile
  (defalias 'w3m-setup-menu 'ignore))

(eval-and-compile
  (cond
   ((featurep 'xemacs)
    (require 'w3m-xmas))
   ((>= emacs-major-version 22)
    (require 'w3m-e22))
   ((= emacs-major-version 21)
    (require 'w3m-e21))
   ((= emacs-major-version 20)
    (require 'w3m-e20))
   ((boundp 'MULE)
    (require 'w3m-om))
   (t
    (require 'w3m-e19))))

(require 'w3m-hist)
(require 'timezone)

;; Add-on programs:
(eval-and-compile
  (autoload 'w3m-bookmark-view "w3m-bookmark" nil t)
  (autoload 'w3m-bookmark-add-this-url "w3m-bookmark"
    "Add a link under point to the bookmark." t)
  (autoload 'w3m-bookmark-add-current-url "w3m-bookmark"
    "Add a link address of the current page to the bookmark." t)
  (autoload 'w3m-search "w3m-search"
    "Search a word using search engines." t)
  (autoload 'w3m-search-uri-replace "w3m-search")
  (autoload 'w3m-weather "w3m-weather"
    "Display a weather report." t)
  (autoload 'w3m-about-weather "w3m-weather")
  (autoload 'w3m-antenna "w3m-antenna"
    "Report changes of web sites." t)
  (autoload 'w3m-antenna-add-current-url "w3m-antenna"
    "Add a link address of the current page to the antenna database." t)
  (autoload 'w3m-about-antenna "w3m-antenna")
  (autoload 'w3m-dtree "w3m-dtree"
    "Display a directory tree." t)
  (autoload 'w3m-about-dtree "w3m-dtree")
  (autoload 'w3m-namazu "w3m-namazu"
    "Search files with Namazu." t)
  (autoload 'w3m-about-namazu "w3m-namazu")
  (autoload 'w3m-perldoc "w3m-perldoc"
    "View Perl documents" t)
  (autoload 'w3m-about-perldoc "w3m-perldoc")
  (autoload 'w3m-fontify-forms "w3m-form")
  (autoload 'w3m-fontify-textareas "w3m-form")
  (autoload 'w3m-filter "w3m-filter")
  (autoload 'w3m-setup-tab-menu "w3m-tabmenu")
  (autoload 'w3m-switch-buffer "w3m-tabmenu")
  (autoload 'w3m-cookie-set "w3m-cookie")
  (autoload 'w3m-cookie-get "w3m-cookie")
  (autoload 'w3m-cookie "w3m-cookie")
  (autoload 'w3m-about-cookie "w3m-cookie")
  (autoload 'w3m-cookie-shutdown "w3m-cookie" nil t)
  (autoload 'report-emacs-w3m-bug "w3m-bug" nil t)
  (autoload 'w3m-replace-symbol "w3m-symbol" nil t)
  (autoload 'widget-forward "wid-edit" nil t))

;; Avoid byte-compile warnings.
(eval-when-compile
  (autoload 'rfc2368-parse-mailto-url "rfc2368")
  (autoload 'widget-convert-button "wid-edit")
  (unless (fboundp 'char-to-int)
    (defalias 'char-to-int 'identity)))

(defconst emacs-w3m-version
  (eval-when-compile
    (let ((rev "$Revision$"))
      (and (string-match "\\.\\([0-9]+\\) \\$\\'" rev)
	   (setq rev (- (string-to-number (match-string 1 rev)) 1030))
	   (concat "1.4.0" (if (>= rev 0) (format ".%d" (+ rev 50)) "")))))
  "Version number of this package.")

(defgroup w3m nil
  "Emacs-w3m - the web browser of choice."
  :group 'hypermedia)

(defgroup w3m-face nil
  "Faces used for emacs-w3m."
  :group 'w3m
  :prefix "w3m-")

(defcustom w3m-command nil
  "*Name of the executable file of the w3m command.
You normally don't have to specify the value, since emacs-w3m looks
for the existing commands in order of w3m, w3mmee and w3m-m17n in the
`exec-path' directories in order if it is nil in the beginning.

If you want to use the other w3m command, specify the value of this
variable explicitly in the .emacs file or customize the value and save
it.  In this case, you need to restart Emacs and emacs-w3m.  That is,
there is currently no way to apply the changing of the w3m command to
all the emacs-w3m programs safely after loading the w3m.elc module."
  :group 'w3m
  :type '(radio (const :format "Not specified " nil)
		(string :format "Command: %v\n" :size 0)))

(defvar w3m-type nil
  "Type of the w3m command.
The valid values include `w3m', `w3mmee', and `w3m-m17n'.")
(defvar w3m-compile-options nil
  "Compile options that the w3m command was built with.")
(defvar w3m-version nil
  "Version string of the w3m command.")

;; Set w3m-command, w3m-type, w3m-version and w3m-compile-options
(if noninteractive ;; Don't call the external command when compiling.
    (unless w3m-command
      (setq w3m-command "w3m"))
  (when (or (null w3m-command)
	    (null w3m-type)
	    (null w3m-version)
	    (null w3m-compile-options))
    (let ((command (or w3m-command
		       (w3m-which-command "w3m")
		       (w3m-which-command "w3mmee")
		       (w3m-which-command "w3m-m17n"))))
      (when command
	(setq w3m-command command)
	(with-temp-buffer
	  (call-process command nil t nil "-version")
	  (goto-char (point-min))
	  (when (re-search-forward "version \\(w3m/0\\.[3-9]\
\\(\\.[0-9\\]\\)*\\(rc[0-9]+\\)?\
\\(-stable\\|\\(\\+cvs\\(-[0-9]+\\.[0-9]+\\)?\\)\\)?\
\\(-inu\\|\\(-m17n\\|\\(\\+mee\\)\\)\\)?[^,]*\\)" nil t)
	    (setq w3m-version (match-string 1))
	    (setq w3m-type
		  (cond
		   ((match-beginning 9) 'w3mmee)
		   ((match-beginning 8) 'w3m-m17n)
		   ((match-beginning 1) 'w3m)
		   (t 'other))))
	  (when (re-search-forward "options +" nil t)
	    (setq w3m-compile-options
		  (or (split-string (buffer-substring
				     (match-end 0)
				     (save-excursion (end-of-line)
						     (point)))
				    ",")
		      (list nil)))
	    (when (member "m17n" w3m-compile-options)
	      (setq w3m-type 'w3m-m17n))))))))

(when (not (stringp w3m-command))
  (error "\
Install w3m command in `exec-path' or set `w3m-command' variable correctly"))

(defcustom w3m-user-agent (concat "Emacs-w3m/" emacs-w3m-version
				  " " w3m-version)
  "String used for the User-Agent field.  See also `w3m-add-user-agent'."
  :group 'w3m
  :type '(string :size 0))

(defcustom w3m-add-user-agent t
  "Non-nil means add the User-Agent field to the request header.
The value of `w3m-user-agent' is used for the field body."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-language
  (if (or (and (boundp 'current-language-environment)
	       (string= "Japanese"
			(symbol-value 'current-language-environment)))
	  (boundp 'MULE))
      "Japanese")
  "*Your preferred language used in emacs-w3m sessions."
  :group 'w3m
  :type '(radio (const :format "%v " "Japanese")
		(const :tag "Other" nil))
  :get (lambda (symbol)
	 (let ((value (format "%s" (default-value symbol)))
	       (case-fold-search t))
	   (prog1
	       (setq value (if (string-match "\\`japan" value) "Japanese"))
	     (set-default symbol value))))
  :set (lambda (symbol value)
	 (set-default symbol (if (equal value "Japanese") "Japanese"))))

(defcustom w3m-command-arguments
  (if (eq w3m-type 'w3mmee) '("-o" "concurrent=0" "-F") nil)
  "*List of the default arguments passed to the w3m command.
See also `w3m-command-arguments-alist'."
  :group 'w3m
  :type '(repeat (string :format "Argument: %v\n" :size 0)))

(defcustom w3m-command-arguments-alist nil
  "*Alist of regexps matching urls and additional arguments passed to w3m.
A typical usage of this variable is to specify whether to use the proxy
server for the particular hosts.  The first match made will be used.
Here is an example of how to set this variable:

\(setq w3m-command-arguments-alist
      '(;; Don't use the proxy server to visit local web pages.
	(\"^http://\\\\([^/]*\\\\.\\\\)*your-company\\\\.com\\\\(/\\\\|$\\\\)\"
	 \"-no-proxy\")
	;; Use the proxy server to visit any foreign urls.
	(\"\"
	 \"-o\" \"http_proxy=http://proxy.your-company.com:8080/\")))

Where the first element matches the url that the scheme is \"http\" and
the hostname is either \"your-company.com\" or a name ended with
\".your-company.com\", and the proxy server is not used for those hosts.
If you are a novice on the regexps, you can use the
`w3m-no-proxy-domains' variable instead."
  :group 'w3m
  :type '(repeat (cons :format "%v" :indent 4
		       (regexp :format "%t: %v\n" :size 0)
		       (repeat :tag "Arguments passed to w3m command"
			       (string :format "Arg: %v\n" :size 0)))))

(defcustom w3m-no-proxy-domains nil
  "*List of domain names with which emacs-w3m will not use a proxy server.
Each element should be exactly a domain name which means the latter
common part of the host names, not a regexp."
  :group 'w3m
  :type '(repeat (string :format "Domain name: %v\n" :size 0)))

(defcustom w3m-command-environment
  (delq nil
	(list
	 (if (eq w3m-type 'w3mmee)
	     (cons "W3MLANG" "ja_JP.kterm"))
	 (if (eq system-type 'windows-nt)
	     (cons "CYGWIN" "binmode tty"))))
  "*Alist of environment variables for subprocesses to inherit."
  :group 'w3m
  :type '(repeat
	  (cons :format "%v" :indent 4
		(string :format "Name: %v\n" :size 0)
		(string :format "    Value: %v\n" :size 0))))

(defcustom w3m-fill-column -1
  "*Integer used as the value for `fill-column' in emacs-w3m buffers.
If it is positive, pages will be displayed within the columns of that
number.  If it is zero or negative, the number of columns which
subtracted that number from the window width is applied to the maximum
width of pages.  Note that XEmacs does not always obey this setting."
  :group 'w3m
  :type '(integer :size 0))

(defcustom w3m-mailto-url-function nil
  "*Function used to handle the `mailto' urls.
Function is called with one argument, just a url.  If it is nil, a
function specified by the `mail-user-agent' variable will be used for
composing mail messages."
  :group 'w3m
  :type '(radio (const :tag "Not specified" nil)
		(function :format "%t: %v\n" :size 0)))

(defcustom w3m-mailto-url-popup-function-alist
  '((cmail-mail-mode . pop-to-buffer)
    (mail-mode . pop-to-buffer)
    (message-mode . pop-to-buffer)
    (mew-draft-mode . pop-to-buffer)
    (mh-letter-mode . pop-to-buffer)
    (wl-draft-mode . pop-to-buffer))
  "*Alist of (MAJOR-MODE . FUNCTION) pairs used to pop to a mail buffer up.
If a user clicks on a `mailto' url and a mail buffer is composed by
`mail-user-agent' with the MAJOR-MODE, FUNCTION will be called with a
mail buffer as an argument.  Note that the variables
`special-display-buffer-names', `special-display-regexps',
`same-window-buffer-names' and `same-window-regexps' will be bound to
nil while popping to a buffer up."
  :group 'w3m
  :type '(repeat (cons :format "%v" :indent 11
		       (symbol :format "Major-mode: %v\n" :size 0)
		       (function :format "%t: %v\n" :size 0))))

(defcustom w3m-use-mule-ucs
  (and (eq w3m-type 'w3m) (featurep 'un-define))
  "*Non-nil means use the multi-script support with Mule-UCS."
  :group 'w3m
  :type 'boolean
  :require 'w3m-ucs)

(when w3m-use-mule-ucs
  (condition-case nil
      (require 'w3m-ucs)
    (error (setq w3m-use-mule-ucs nil))))

(defcustom w3m-use-ange-ftp nil
  "*Non-nil means that `ange-ftp' or `efs' is used to access FTP servers."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-imitate-widget-button '(eq major-mode 'gnus-article-mode)
  "*If non-nil, imitate the widget buttons on link (anchor) buttons.
It is useful for moving about in a Gnus article buffer using TAB key.
It can also be any Lisp form that should return a boolean value."
  :group 'w3m
  :type '(sexp :size 0))

(defcustom w3m-treat-image-size t
  "*Non-nil means let w3m mind the ratio of the size of images and text.

If it is non-nil, the w3m command will make a halfdump which reserves
rectangle spaces in which images will be put, and also `alt' texts
will be truncated or padded with spaces so that their display width
will be the same as the width of images.

See also `w3m-pixels-per-character' and `w3m-pixels-per-line'.  Those
values will be passed to the w3m command in order to compute columns
and lines which images occupy."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-pixels-per-line 64
  "*Integer used for the `-ppl' argument of the w3m command.
If nil, the height of the default face is used.  It is valid only when
`w3m-treat-image-size' is non-nil.  Note that a small value may not
induce a good result.  If you want to use emacs-w3m in a character
terminal and make `w3m-treat-image-size' effective, you need to set
this variable properly."
  :group 'w3m
  :type '(choice (const :tag "Auto Detect" nil)
		 (integer :tag "Specify Pixels")))

(defcustom w3m-pixels-per-character nil
  "*Integer used for the `-ppc' argument of the w3m command.
If nil, the width of the default face is used.  It is valid only when
`w3m-treat-image-size' is non-nil.  If you want to use emacs-w3m in a
character terminal and make `w3m-treat-image-size' effective, you need
to set this variable properly."
  :group 'w3m
  :type '(radio (const :tag "Auto Detect" nil)
		(integer :format "Specify Pixels: %v\n" :size 0)))

(defvar w3m-accept-japanese-characters
  (and (not noninteractive)
       (featurep 'mule)
       (or (memq w3m-type '(w3mmee w3m-m17n))
	   ;; Examine whether the w3m command specified by `w3m-command'
	   ;; uses `euc-japan' for the internal character set.
	   (let ((str
		  (eval-when-compile
		    (format
		     (concat
		      "<!doctype html public \"-//W3C//DTD HTML 3.2//EN\">"
		      "<html><head><meta http-equiv=\"Content-Type\" "
		      "content=\"text/html; charset=ISO-2022-JP\">"
		      "</head><body>%s</body>\n")
		     (string 27 36 66 52 65 59 122 27 40 66)))))
	     (with-temp-buffer
	       (set-buffer-multibyte nil)
	       (insert str)
	       (let ((coding-system-for-write 'binary)
		     (coding-system-for-read 'binary)
		     (default-process-coding-system (cons 'binary 'binary)))
		 (call-process-region (point-min) (point-max) w3m-command
				      t t nil "-T" "text/html" "-halfdump")
		 (goto-char (point-min))
		 (and (re-search-forward (string ?\264 ?\301 ?\273 ?\372)
					 nil t)
		      t))))))
  "Non-nil means that the w3m command accepts Japanese characters.")

(defcustom w3m-coding-system (if (featurep 'mule)
				 (if (eq w3m-type 'w3mmee)
				     'iso-2022-7bit-ss2
				   'iso-2022-7bit)
			       'iso-8859-1)
  "*Default coding system used to communicate with the w3m command."
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-terminal-coding-system
  (if w3m-accept-japanese-characters
      'euc-japan 'iso-8859-1)
  "*Default coding system used when writing to w3m processes.
It is just a default value to set process' coding system initially.
\(This variable name is analogically derived from the behavior of the
w3m command which accepts data from Emacs just like reads from the
terminal.)"
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-output-coding-system
  (cond
   ((not (featurep 'mule)) 'iso-8859-1)
   ((eq w3m-type 'w3mmee) 'ctext)
   ((eq w3m-type 'w3m-m17n)
    (if (or (equal "Japanese" w3m-language)
	    (not (w3m-find-coding-system 'utf-8)))
	'iso-2022-7bit-ss2
      'utf-8))
   (w3m-accept-japanese-characters 'w3m-euc-japan)
   (t 'w3m-iso-latin-1))
  "*Coding system used when reading from w3m processes."
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-input-coding-system
  (if (memq w3m-type '(w3mmee w3m-m17n))
      w3m-output-coding-system
    (if w3m-accept-japanese-characters
	(if w3m-use-mule-ucs
	    'w3m-euc-japan-mule-ucs
	  (if (featurep 'w3m-e21)
	      'w3m-euc-japan
	    'euc-japan))
      (if w3m-use-mule-ucs
	  'w3m-iso-latin-1-mule-ucs
	(if (featurep 'w3m-e21)
	    'w3m-iso-latin-1
	  'iso-8859-1))))
  "*Coding system used when writing to w3m processes.
It overrides `coding-system-for-write' if it is not `binary'.
Otherwise, the value of the `w3m-current-coding-system' variable is
used instead."
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-file-coding-system (if (featurep 'mule)
				      'iso-2022-7bit
				    'iso-8859-1)
  "*Coding system used when writing configuration files.
This value will be referred to by the `w3m-save-list' function."
  :group 'w3m
  :type '(coding-system :size 0))

(defvar w3m-file-coding-system-for-read nil
  "*Coding system used when reading configuration files.
It is strongly recommended that you do not set this variable if there
is no particular reason.  The value will be referred to by the
`w3m-load-list' function.")

(defcustom w3m-file-name-coding-system
  (if (memq system-type '(windows-nt OS/2 emx))
      'shift_jis 'euc-japan)
  "*Coding system used to convert pathnames when emacs-w3m accesses files."
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-default-coding-system
  (if (equal "Japanese" w3m-language) 'shift_jis 'iso-8859-1)
  "*Default coding system used to encode url strings and post-data."
  :group 'w3m
  :type '(coding-system :size 0))

(defcustom w3m-coding-system-priority-list
  (if (equal "Japanese" w3m-language) '(shift_jis))
  "*Coding systems in order of priority used for emacs-w3m sessions."
  :group 'w3m
  :type '(repeat (coding-system :format "%t: %v\n" :size 0)))

(defcustom w3m-key-binding nil
  "*Type of key binding set used in emacs-w3m sessions.
The valid values include `info' which provides Info-like keys, and
nil which provides Lynx-like keys."
  :group 'w3m
  :type '(choice
	  (const :tag "Use Info-like key mapping." info)
	  (const :tag "Use Lynx-like key mapping." nil))
  ;; Since the following form won't be byte-compiled, you developers
  ;; should never use CL macros like `caaaar', `when', `unless' ...
  :set (lambda (symbol value)
	 (prog1
	     ;; XEmacs 21.4.8 or Emacs 19 don't have `custom-set-default'.
	     (set-default symbol value)
	   (if (or noninteractive
		   ;; Loading w3m.elc is just in progress...
		   (not (featurep 'w3m)))
	       nil
	     (if (and;; Gnus binds `w3m-mode-map' for compiling.
		  (boundp 'w3m-mode-map)
		  (boundp 'w3m-info-like-map)
		  (boundp 'w3m-lynx-like-map))
		 ;; It won't be bound at the first time.
		 (eval
		  '(setq w3m-mode-map (if (eq value 'info)
					  w3m-info-like-map
					w3m-lynx-like-map)
			 w3m-minor-mode-map (w3m-make-minor-mode-keymap))))
	     (let ((buffers (buffer-list)))
	       (save-excursion
		 (while buffers
		   (set-buffer (car buffers))
		   (if (eq major-mode 'w3m-mode)
		       (condition-case nil
			   (progn
			     (use-local-map (symbol-value 'w3m-mode-map))
			     (w3m-setup-toolbar)
			     (w3m-setup-menu))
			 (error)))
		   (setq buffers (cdr buffers)))))))))

(defcustom w3m-use-cygdrive (eq system-type 'windows-nt)
  "*If non-nil, use the /cygdrive/ rule when performing `expand-file-name'."
  :group 'w3m
  :type 'boolean)

(defconst w3m-treat-drive-letter (memq system-type '(windows-nt OS/2 emx))
  "Say whether the system uses drive letters.")

(defcustom w3m-profile-directory
  (concat "~/." (file-name-sans-extension
		 (file-name-nondirectory w3m-command)))
  "*Directory where emacs-w3m config files are loaded from or saved to."
  :group 'w3m
  :type '(directory :size 0))

(defcustom w3m-init-file "~/.emacs-w3m"
  "*Your emacs-w3m startup file name.
If a file with the `.el' or `.elc' suffixes exists, it will be read
instead.

Note: This file is used as the startup configuration *NOT* for the w3m
command but for emacs-w3m.  In order to modify configurations for the
w3m command, edit the file named \"~/.w3m/config\" normally."
  :group 'w3m
  :type '(file :size 0))

(defcustom w3m-default-save-directory
  (concat "~/." (file-name-sans-extension
		 (file-name-nondirectory w3m-command)))
  "*Default directory where downloaded files will be saved to."
  :group 'w3m
  :type '(directory :size 0))

(defcustom w3m-accept-languages
  (let ((file (expand-file-name "config" w3m-profile-directory)))
    (or (when (file-readable-p file)
	  (with-temp-buffer
	    (insert-file-contents file)
	    (goto-char (point-min))
	    (when (re-search-forward "^accept_language[\t ]+\\(.+\\)$" nil t)
	      (delete "" (split-string (match-string 1)
				       "[ \t\r\f\n]*,[ \t\r\f\n]*")))))
	(when (string= w3m-language "Japanese")
	  '("ja" "en"))))
  "*List of acceptable languages in descending order of priority.
The default value is set according to the accept_language entry of the
w3m configuration file (normally \"~/.w3m/config\")."
  :group 'w3m
  :type '(repeat (string :format "Lang: %v\n" :size 0)))

(defcustom w3m-delete-duplicated-empty-lines t
  "*Non-nil means display two or more continuous empty lines into single."
  :group 'w3m
  :type 'boolean)

(defvar w3m-display-inline-images nil
  "Internal variable controls whether to show images in emacs-w3m buffers.
This variable is buffer-local which defaults to the value of
`w3m-default-display-inline-images'.  Don't set it directly; modify
the `w3m-default-display-inline-images' variable or use the\
 `\\<w3m-mode-map>\\[w3m-toggle-inline-images]' command
to change the appearance of images.
See also `w3m-toggle-inline-images-permanently'.")
(make-variable-buffer-local 'w3m-display-inline-images)

(defcustom w3m-default-display-inline-images nil
  "*Non-nil means display images inline in emacs-w3m buffers.
You can toggle the visibility of images by the\
 `\\<w3m-mode-map>\\[w3m-toggle-inline-images]' command.
See also `w3m-toggle-inline-images-permanently'."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-toggle-inline-images-permanently t
  "*Non-nil means let the visibility of images continue permanently.
The visibility of images is initialized according to
`w3m-default-display-inline-images' at the first time, and except that
it may be toggled by the `\\<w3m-mode-map>\\[w3m-toggle-inline-images]'\
 command, it does not change hereafter, if
it is non-nil.  Otherwise, whether images are visible is initialized
according to `w3m-default-display-inline-images' whenever you visit a
new page or reload the current page in an emacs-w3m buffer."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-icon-directory
  (if (fboundp 'locate-data-directory)
      (locate-data-directory "w3m")
    (let ((icons (expand-file-name "w3m/icons/"
				   data-directory)))
      (if (file-directory-p icons)
	  icons)))
  "*Directory where emacs-w3m should find icon files."
  :group 'w3m
  :type '(radio (const :tag "Not specified")
		(directory :format "%t: %v\n" :size 0)))

(defcustom w3m-broken-proxy-cache nil
  "*Set it to t if the proxy server seems not to work properly in caching.
Note that this may be the double-edged sword; setting it to t will
likely be harmful if the proxy server sends bad requests (e.g., not
including the Host header, see RFC2616 section 14.23) to foreign
servers when the w3m command specifies the \"no-cache\" directive.  Also
note that it may not be effective if you are using old w3m command."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-quick-start t
  "*Non-nil means let emacs-w3m start quickly w/o requiring confirmation.
When you invoke the `w3m' command, it attempts to visit the page of a
string like url around the cursor or the value of `w3m-home-page'.
You won't be asked for the confirmation then if this value is non-nil.
Otherwise, you will be prompted for that url with the editing form."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-home-page
  (or (getenv "HTTP_HOME")
      (getenv "WWW_HOME")
      "about:")
  "*This variable specifies the url string to open when emacs-w3m starts.
Don't say HP, which is the abbreviated name of a certain company. ;-)"
  :group 'w3m
  :type '(list :convert-widget
	       (lambda (widget)
		 `(radio :args
			 ,(append
			   (if (getenv "HTTP_HOME")
			       (list (list 'const
					   :format "HTTP_HOME: \"%v\"\n"
					   (getenv "HTTP_HOME"))))
			   (if (getenv "WWW_HOME")
			       (list (list 'const
					   :format "WWW_HOME: \"%v\"\n"
					   (getenv "WWW_HOME"))))
			   '((const :tag "About emacs-w3m" "about:")
			     (const :tag "Blank page" "about:blank")
			     (string :format "URL: %v\n" :size 0)))))))

(defcustom w3m-arrived-file
  (expand-file-name ".arrived" w3m-profile-directory)
  "*Name of the file to keep the arrived URLs database."
  :group 'w3m
  :type '(file :size 0))

(defcustom w3m-keep-arrived-urls 500
  "*Maximum number of URLs which the arrived URLs database keeps."
  :group 'w3m
  :type '(integer :size 0))

(defcustom w3m-prefer-cache nil
  "*Non-nil means that cached contents are used without checking headers."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-keep-cache-size 300
  "*Maximum number of pages to be cached in emacs-w3m."
  :group 'w3m
  :type '(integer :size 0))

(defcustom w3m-follow-redirection 9
  "*Maximum number of redirections which emacs-w3m honors and follows.
If nil, redirections are followed by the w3m command.  Don't set it to
nil if you allow to use cookies (i.e., you have set `w3m-use-cookies'
to non-nil) since cookies may be shared among many redirected pages."
  :group 'w3m
  :type '(radio (const :format "Ignore redirections " nil)
		(integer :size 0)))

(defcustom w3m-redirect-with-get t
  "*If non-nil, use the GET method after redirection.
It controls how emacs-w3m works when a server responds the code 301 or
302.  Here is an extract from RFC2616:

Note: RFC 1945 and RFC 2068 specify that the client is not allowed
to change the method on the redirected request.  However, most
existing user agent implementations treat 302 as if it were a 303
response, performing a GET on the Location field-value regardless
of the original request method."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-resize-image-scale 50
  "*Number of steps in percent used when resizing images."
  :group 'w3m
  :type '(integer :size 0))

(defface w3m-anchor-face
  '((((class color) (background light)) (:foreground "blue"))
    (((class color) (background dark)) (:foreground "cyan"))
    (t (:underline t)))
  "Face used for displaying anchors."
  :group 'w3m-face)

(defface w3m-arrived-anchor-face
  '((((class color) (background light)) (:foreground "navy"))
    (((class color) (background dark)) (:foreground "LightSkyBlue"))
    (t (:underline t)))
  "Face used for displaying anchors which have already arrived."
  :group 'w3m-face)

(defface w3m-current-anchor-face
  '((t (:underline t :bold t)))
  "Face used to highlight the current anchor."
  :group 'w3m-face)

(defface w3m-image-face
  '((((class color) (background light)) (:foreground "ForestGreen"))
    (((class color) (background dark)) (:foreground "PaleGreen"))
    (t (:underline t)))
  "Face used for displaying alternate strings of images."
  :group 'w3m-face)

(defface w3m-history-current-url-face
  ;; The following strange code compounds the attributes of the
  ;; `secondary-selection' face and the `w3m-arrived-anchor-face' face,
  ;; and generates the new attributes for this face.
  (let ((base 'secondary-selection)
	(fn (if (featurep 'xemacs)
		'face-custom-attributes-get
	      'custom-face-attributes-get));; What a perverseness it is.
	;; Both `face-custom-attributes-get' in XEmacs and
	;; `custom-face-attributes-get' in CUSTOM 1.9962 attempt to
	;; require `font' in Emacs/w3 and `cl' arbitrarily. :-/
	(features (cons 'font features))
	base-attributes attributes attribute)
    (require 'wid-edit) ;; Needed only in Emacs 20.
    (setq base-attributes (funcall fn base nil)
	  attributes (funcall fn 'w3m-arrived-anchor-face nil))
    (while base-attributes
      (setq attribute (car base-attributes))
      (unless (memq attribute '(:foreground :underline))
	(setq attributes (plist-put attributes attribute
				    (cadr base-attributes))))
      (setq base-attributes (cddr base-attributes)))
    (list (list t attributes)))
  "Face used to highlight the current url in the \"about://history/\" page."
  :group 'w3m-face)

(defface w3m-bold-face `((t (,@w3m-default-face-colors :bold t)))
  "Face used for displaying bold text."
  :group 'w3m-face)

(defface w3m-underline-face `((t (,@w3m-default-face-colors :underline t)))
  "Face used for displaying underlined text."
  :group 'w3m-face)

(defface w3m-strike-through-face
  `((t (,@w3m-default-face-colors ,(if (featurep 'xemacs)
				       :strikethru
				     :strike-through)
				  t)))
  "Face used for displaying strike-through text."
  :group 'w3m-face)

(defvar w3m-fontify-strike-through (or (featurep 'w3m-e21)
				       (featurep 'w3m-xmas))
  "Non-nil means use `strike-through' attribute to display deleted text.")

(defcustom w3m-mode-hook nil
  "*Hook run after `w3m-mode' initialization.
This hook is evaluated by the `w3m-mode' function."
  :group 'w3m
  :type 'hook)

(defcustom w3m-fontify-before-hook nil
  "*Hook run when starting to fontify emacs-w3m buffers.
This hook is evaluated by the `w3m-fontify' function."
  :group 'w3m
  :type 'hook)

(defcustom w3m-fontify-after-hook nil
  "*Hook run after fontifying emacs-w3m buffers.
This hook is evaluated by the `w3m-fontify' function."
  :group 'w3m
  :type 'hook)

(defcustom w3m-display-hook
  '(w3m-move-point-for-localcgi
    w3m-history-highlight-current-url)
  "*Hook run after displaying pages in emacs-w3m buffers.
Each function is called with a url string as the argument.  This hook
is evaluated by the `w3m-goto-url' function."
  :group 'w3m
  :type 'hook
  :initialize 'w3m-custom-hook-initialize)

(defcustom w3m-after-cursor-move-hook
  '(w3m-highlight-current-anchor
    w3m-print-this-url
    w3m-auto-show)
  "*Hook run each time after the cursor moves in emacs-w3m buffers.
This hook is called by the `w3m-check-current-position' function by
way of `post-command-hook'."
  :group 'w3m
  :type 'hook
  :initialize 'w3m-custom-hook-initialize)

(defcustom w3m-delete-buffer-hook
  '(w3m-pack-buffer-numbers)
  "*Hook run when every emacs-w3m buffer is deleted."
  :group 'w3m
  :type 'hook
  :initialize 'w3m-custom-hook-initialize)

(defcustom w3m-select-buffer-hook nil
  "*Hook run when a different emacs-w3m buffer is selected."
  :group 'w3m
  :type 'hook)

(defcustom w3m-async-exec t
  "*Non-nil means execute the w3m command asynchronously in Emacs process."
  :group 'w3m
  :type 'boolean)

;; As far as we know, Emacs 20/21 under Mac OS X[1] and XEmacs under
;; Solaris[2] won't run the asynchronous operations correctly when
;; both `w3m-async-exec' and `w3m-process-connection-type' are non-nil;
;; [1]the final kilobyte or so might get lost from raw data downloaded
;; from a web site; [2]XEmacs hangs up.

(defcustom w3m-process-connection-type
  (not (or (and (memq system-type '(darwin macos))
		(let ((ver (shell-command-to-string "uname -r")))
		  (and (string-match "^\\([0-9]+\\)\\." ver)
		       (< (string-to-number (match-string 1 ver)) 7))))
	   (and (featurep 'xemacs)
		(string-match "solaris" system-configuration))))
  "*Value for `process-connection-type' used when communicating with w3m."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-default-content-type "text/html"
  "*Default value assumed as the content type of local files."
  :group 'w3m
  :type '(string :size 0))

(defvar w3m-image-viewer
  (or (w3m-which-command "display")
      (w3m-which-command "eeyes")
      (w3m-which-command "xloadimage")
      (w3m-which-command "xv"))
  "*Command used to view image files externally.
Note that this option is installed temporally.  It will be abolished
when we implement the mailcap parser to set `w3m-content-type-alist'.")

;; FIXME: we need to improve so that to set up the value of this
;; variable may be performed by parsing the mailcap file.
(defcustom w3m-content-type-alist
  (let* ((fiber-viewer (when (eq system-type 'windows-nt)
			 (list "fiber.exe" "-s" 'file)))
	 (external-browser
	  (if (eq system-type 'windows-nt)
	      'w3m-w32-browser-with-fiber
	    (or (when (condition-case nil (require 'browse-url) (error nil))
		  (if (or (not (boundp 'browse-url-browser-function))
			  (eq 'w3m-browse-url
			      (symbol-value 'browse-url-browser-function)))
		      (cond
		       ((fboundp 'browse-url-default-browser)
			'browse-url-default-browser)
		       ((fboundp 'browse-url-netscape)
			'browse-url-netscape))
		    (symbol-value 'browse-url-browser-function)))
		(when (w3m-which-command "netscape")
		  (list "netscape" 'url)))))
	 (image-viewer (or fiber-viewer
			   (when w3m-image-viewer
			     (list w3m-image-viewer 'file))))
	 (video-viewer (or fiber-viewer
			   (when (w3m-which-command "mpeg_play")
			     (list "mpeg_play" 'file))))
	 (ps-viewer (or fiber-viewer
			(cond
			 ((w3m-which-command "gv") (list "gv" 'file))
			 ((w3m-which-command "gs") (list "gs" 'file)))))
	 (pdf-viewer (or fiber-viewer
			 (cond
			  ((w3m-which-command "xpdf") (list "xpdf" 'file))
			  ((w3m-which-command "acroread")
			   (list "acroread" 'file))))))
    `(("text/plain" "\\.\\(txt\\|tex\\|el\\)\\'" nil nil)
      ("text/html" "\\.s?html?\\'" ,external-browser nil)
      ("image/jpeg" "\\.jpe?g\\'" ,image-viewer nil)
      ("image/png" "\\.png\\'" ,image-viewer nil)
      ("image/gif" "\\.gif\\'" ,image-viewer nil)
      ("image/tiff" "\\.tif?f\\'" ,image-viewer nil)
      ("image/x-xwd" "\\.xwd\\'" ,image-viewer nil)
      ("image/x-xbm" "\\.xbm\\'" ,image-viewer nil)
      ("image/x-xpm" "\\.xpm\\'" ,image-viewer nil)
      ("image/x-bmp" "\\.bmp\\'" ,image-viewer nil)
      ("video/mpeg" "\\.mpe?g\\'" ,video-viewer nil)
      ("video/quicktime" "\\.mov\\'" ,video-viewer nil)
      ("application/postscript" "\\.e?ps\\'" ,ps-viewer nil)
      ("application/pdf" "\\.pdf\\'" ,pdf-viewer nil)
      ("application/xhtml+xml" nil nil "text/html")))
  "*Alist of file suffixes and content types."
  :group 'w3m
  :type '(repeat
	  (group
	   :indent 2
	   (string :format "Type: %v\n" :size 0)
	   (radio :format "%{Regexp%}: %v" :extra-offset 8
		  :sample-face underline
		  (const :tag "Not specified" nil)
		  (regexp :format "String: %v\n" :size 0))
	   (radio :format "%{Viewer%}: %v" :extra-offset 8
		  :sample-face underline
		  (const :tag "Not specified" nil)
		  (cons :tag "External viewer" :extra-offset 2
			(string :format "Command: %v\n" :size 0)
			(repeat :format "Arguments:\n%v%i\n" :extra-offset 2
				(restricted-sexp
				 :format "%v\n"
				 :match-alternatives (stringp 'file 'url)
				 :size 0)))
		  (function :format "%t: %v\n" :size 0))
	   (radio :format "%{Filter%}: %v" :extra-offset 8
		  :sample-face underline
		  (const :tag "Not specified" nil)
		  (string :format "Equivalent type: %v\n" :size 0)
		  (function :format "Function: %v\n" :size 0)))))

;; FIXME: we need to rearrange the complicated and redundant relation of
;; `w3m-encoding-type-alist', `w3m-decoder-alist', and `w3m-encoding-alist'.
(defcustom w3m-encoding-type-alist
  '(("\\.gz\\'" . "gzip")
    ("\\.bz2?\\'" . "bzip"))
  "*Alist of file suffixes and content encoding types."
  :group 'w3m
  :type '(repeat
	  (cons :format "%v" :indent 14
		(string :format "Regexp of Suffixes: %v\n" :size 0)
		(string :format "Encoding Type: %v\n" :size 0))))

(defcustom w3m-decoder-alist
  `((gzip "gzip" ("-d"))	;; Don't use "gunzip" and "bunzip2"
    (bzip "bzip2" ("-d"))	;; for broken OS and implementations.
    (deflate
      ,(if (not noninteractive)
	   (let ((exec-path
		  (let ((prefix (file-name-directory
				 (directory-file-name
				  (file-name-directory
				   (w3m-which-command w3m-command))))))
		    (list (expand-file-name "libexec/w3m" prefix)
			  (expand-file-name "lib/w3m" prefix)))))
	     (w3m-which-command "inflate")))
      nil))
  "Alist of encoding types, decoder commands, and arguments."
  :group 'w3m
  :type '(repeat
	  (group :indent 4
		 (radio :format "Encoding: %v"
			(const :format "%v " gzip)
			(const :format "%v " bzip)
			(const deflate))
		 (string :format "Command: %v\n" :size 0)
		 (repeat :tag "Arguments" :extra-offset 2
			 (string :format "%v\n" :size 0)))))

(defcustom w3m-charset-coding-system-alist
  (let ((rest
	 '((us_ascii      . raw-text)
	   (us-ascii      . raw-text)
	   (gb2312	  . cn-gb-2312)
	   (cn-gb	  . cn-gb-2312)
	   (iso-2022-jp-2 . iso-2022-7bit-ss2)
	   (iso-2022-jp-3 . iso-2022-7bit-ss2)
	   (tis-620	  . tis620)
	   (windows-874	  . tis-620)
	   (cp874	  . tis-620)
	   (x-ctext       . ctext)
	   (unknown       . undecided)
	   (x-unknown     . undecided)
	   (windows-1250  . cp1250)
	   (windows-1251  . cp1251)
	   (windows-1252  . cp1252)
	   (windows-1253  . cp1253)
	   (windows-1254  . cp1254)
	   (windows-1255  . cp1255)
	   (windows-1256  . cp1256)
	   (windows-1257  . cp1257)
	   (windows-1258  . cp1258)
	   (euc-jp	  . euc-japan)
	   (shift-jis     . shift_jis)
	   (shift_jis     . shift_jis)
	   (sjis	  . shift_jis)
	   (x-euc-jp      . euc-japan)
	   (x-shift-jis   . shift_jis)
	   (x-shift_jis   . shift_jis)
	   (x-sjis	  . shift_jis)))
	dest)
    (while rest
      (or (w3m-find-coding-system (car (car rest)))
	  (setq dest (cons (car rest) dest)))
      (setq rest (cdr rest)))
    dest)
  "Alist of MIME charsets and coding systems.
Both charsets and coding systems must be symbols."
  :group 'w3m
  :type '(repeat (cons :format "%v" :indent 2
		       (symbol :format "%t: %v\n" :size 0)
		       (coding-system :format "%t: %v\n" :size 0))))

(defcustom w3m-correct-charset-alist
  '(("windows-874"  . "tis-620")
    ("cp874"	    . "tis-620")
    ("cp1250" . "windows-1250")
    ("cp1251" . "windows-1251")
    ("cp1252" . "windows-1252")
    ("cp1253" . "windows-1253")
    ("cp1254" . "windows-1254")
    ("cp1255" . "windows-1255")
    ("cp1256" . "windows-1256")
    ("cp1257" . "windows-1257")
    ("cp1258" . "windows-1258")
    ("shift-jis"    . "shift_jis")
    ("sjis"	    . "shift_jis")
    ("x-euc-jp"     . "euc-jp")
    ("x-shift-jis"  . "shift_jis")
    ("x-shift_jis"  . "shift_jis")
    ("x-sjis"	    . "shift_jis"))
  "Alist of MIME charsets; strange ones and standard ones."
  :group 'w3m
  :type '(repeat (cons :format "%v" :indent 11
		       (string :format "From: %v\n" :size 0)
		       (string :format "To: %v\n" :size 0))))

(defcustom w3m-horizontal-scroll-columns 10
  "*Number of steps in columns used when scrolling a window horizontally."
  :group 'w3m
  :type '(integer :size 0))

(defcustom w3m-horizontal-shift-columns 2
  "*Number of steps in columns used when shifting a window horizontally.
The term `shifting' means a fine level scrolling."
  :group 'w3m
  :type '(integer :size 0))

(defcustom w3m-use-form t
  "*Non-nil means make it possible to use form extensions. (EXPERIMENTAL)"
  :group 'w3m
  :type 'boolean
  :require 'w3m-form)

(defcustom w3m-use-cookies nil
  "*Non-nil means enable emacs-w3m to use cookies.  (EXPERIMENTAL)"
  :group 'w3m
  :type 'boolean)

(defcustom w3m-use-filter nil
  "*Non-nil means use filter programs to convert web contents.
See also `w3m-filter-rules'."
  :group 'w3m
  :type 'boolean
  :require 'w3m-filter)

(defcustom w3m-use-symbol
  (and (featurep 'mule)
       (eq w3m-type 'w3m-m17n)
       (or (not (eq w3m-output-coding-system 'utf-8))
	   (and (w3m-mule-unicode-p)
		(>= emacs-major-version 21)
		(or window-system (eq (terminal-coding-system) 'utf-8))))
       t)
  "*Non-nil means replace symbols that the <_SYMBOL> tags lead into.
It is meaningful only when the w3m-m17n command is used and (X)Emacs
handles unicode charsets."
  :group 'w3m
  :type 'boolean
  :require 'w3m-symbol)

(defcustom w3m-edit-function 'find-file
  "*Function used for editing local files.
It is used when either `w3m-edit-current-url' or `w3m-edit-this-url'
is invoked for local pages."
  :group 'w3m
  :type '(radio
	  (const :tag "Edit it in the current window" find-file)
	  (const :tag "Edit it in another window" find-file-other-window)
	  (const :tag "Edit it in another frame" find-file-other-frame)
	  (const :tag "View it in another window" view-file-other-window)
	  (function :format "Other function: %v\n" :size 0
		    :value view-file)))

(defcustom w3m-edit-function-alist
  '(("\\`[^?]+/hiki\\.cgi\\?" . hiki-edit-url))
  "*Alist of functions used for editing pages.
This option is refered to decide which function shouled be used to
edit a specified page, when either `w3m-edit-current-url' or
`w3m-edit-this-url' is invoked.  When no suitable function is found
from this alist, `w3m-edit-function' is used."
  :group 'w3m
  :type '(repeat (cons :format "%v" :indent 3
		       (regexp :format "URL: %v\n" :size 0)
		       (function))))

(defcustom w3m-url-local-directory-alist
  (when (boundp 'yahtml-path-url-alist)
    (mapcar
     (lambda (pair)
       (cons (cdr pair) (car pair)))
     (symbol-value 'yahtml-path-url-alist)))
  "*Alist of URLs and local directories.
If directory names of a given URL and the car of an element are the
same, emacs-w3m assumes that the file exists in the local directory
where the cdr of an element points to.  The default value will be set
to a value of the `yahtml-path-url-alist' variable which exchanged the
car and the cdr in each element if it is available."
  :type '(repeat
	  (cons :format "%v" :indent 3
		(string :format "URL: %v\n" :size 0)
		(directory :format "%t: %v\n" :size 0)))
  :group 'w3m)

(defcustom w3m-track-mouse t
  "*Whether to track the mouse and message the url under the mouse.
This feature does not work under Emacs or XEmacs versions prior to 21.
See also `show-help-function' if you are using Emacs 21.

A tip for XEmacs users:

You can also use the `balloon-help' feature by the
`M-x balloon-help-mode' command with arg 1.  If the window manager
decorates the balloon-help frame, and that is not to your taste, you
may strip it off with the following directives:

For ol[v]wm use this in .Xdefaults:
   olvwm.NoDecor: balloon-help
     or
   olwm.MinimalDecor: balloon-help

For fvwm version 1 use this in your .fvwmrc:
   NoTitle balloon-help
or
   Style \"balloon-help\" NoTitle, NoHandles, BorderWidth 0

For twm use this in your .twmrc:
   NoTitle { \"balloon-help\" }

See the balloon-help.el file for more information."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-use-tab t
  "Non-nil means make emacs-w3m a tab browser.
It makes it possible to show all emacs-w3m buffers in a single window
with the tabs line, and you can choose one by clicking a mouse on it.
Unfortunately, users of Emacs 20 and less cannot enjoy the benefit.
See also `w3m-use-tab-menubar'."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-use-tab-menubar t
  "Non-nil means use the TAB pull-down menu in the menubar.
It makes it possible to show all emacs-w3m buffers in a single window,
and you can choose one by clicking a mouse on it.  This feature
requires that Emacs has been built to be able to display multilingual
text in the menubar if you often visit web sites written in non-ascii
text.  See also `w3m-use-tab'."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-make-new-session nil
  "*Non-nil means making new emacs-w3m buffers when visiting new pages.
If it is non-nil and there are already emacs-w3m buffers, the `w3m'
command makes a new emacs-w3m buffer if a user specifies a url string
in the minibuffer, and the `w3m-safe-view-this-url' command also makes
a new buffer if a user invokes it in a buffer not being running the
`w3m-mode'."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-use-favicon (featurep 'w3m-image)
  "*Non-nil means show favicon images if they are available.
It will be set to nil automatically if ImageMagick's `convert' program
does not support the ico format."
  :get (lambda (symbol)
	 (and (not noninteractive)
	      (default-value symbol)
	      (featurep 'w3m-image)
	      (w3m-favicon-usable-p)))
  :set (lambda (symbol value)
	 (set-default symbol (and (not noninteractive)
				  value
				  (featurep 'w3m-image)
				  (w3m-favicon-usable-p))))
  :group 'w3m
  :type 'boolean)

(defcustom w3m-show-graphic-icons-in-mode-line t
  "Non-nil means show graphic status indicators in the mode-line.
If it is nil, also the favicon won't be shown in the mode-line even if
`w3m-use-favicon' is non-nil."
  :set (lambda (symbol value)
	 (prog1
	     (set-default symbol value)
	   (if (and (not noninteractive)
		    ;; Make sure it is not the first time.
		    (featurep 'w3m)
		    (fboundp 'w3m-initialize-graphic-icons))
	       (w3m-initialize-graphic-icons))))
  :group 'w3m
  :type 'boolean)

(defcustom w3m-show-graphic-icons-in-header-line t
  "Non-nil means show graphic status indicators in the header-line.
If it is nil, also the favicon won't be shown in the header-line even
if `w3m-use-favicon' is non-nil.  This variable is currently
meaningless under XEmacs."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-pop-up-windows t
  "Non-nil means split the windows when a new emacs-w3m session is created.
This variable is similar to `pop-up-windows' and quite overridden by
`w3m-pop-up-frames' as if `pop-up-frames' influences.  Furthermore, if
`w3m-use-tab' is non-nil or there is the buffers selection window (for
the `w3m-select-buffer' feature), this variable is ignored when
creating the second or more emacs-w3m session."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-pop-up-frames nil
  "Non-nil means pop to a new frame up for an emacs-w3m session.
This variable is similar to `pop-up-frames' and does override
`w3m-pop-up-windows'.  If `w3m-use-tab' is non-nil or there is the
buffers selection window (for the `w3m-select-buffer' feature), this
variable is ignored when creating the second or more emacs-w3m session."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-view-this-url-new-session-in-background nil
  "Run `w3m-view-this-url' without switching to the newly created buffer.
It is useful if you enabled the tabs line or the buffers selection
window for the `w3m-select-buffer' feature.  Note that it is meaningful
only when specifying a prefix argument to the `w3m-view-this-url'
command or using the `w3m-view-this-url-new-session' command in order
to create a new emacs-w3m session."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-popup-frame-parameters nil
  "Alist of frame parameters used when creating a new emacs-w3m frame.
It allows not only the alist form but also XEmacs' plist form."
  :group 'w3m
  :type '(choice (group :inline t :tag "Frame Parameters (Emacs)"
			(repeat :inline t :tag "Frame Parameters (Emacs)"
				(cons :format "%v" :indent 3
				      (symbol :format "Parameter: %v\n"
					      :size 0)
				      (sexp :format "%t: %v\n" :size 0))))
		 (group :inline t :tag "Frame Plist (XEmacs)"
			(repeat :inline t :tag "Frame Plist (XEmacs)"
				(group :indent 2 :inline t
				       (symbol :format "Property: %v\n"
					       :size 0)
				       (sexp :format "%t: %v\n" :size 0))))))

(defcustom w3m-auto-show t
  "*Non-nil means provide the ability to horizontally scroll the window.
Automatic horizontal scrolling is made when the point gets away from
both ends of the window, but nothing occurs if `truncate-lines' is set
to nil.

This feature works with the specially made program in emacs-w3m; usual
`auto-hscroll-mode', `automatic-hscrolling', `auto-show-mode' or
`hscroll-mode' will all be invalidated in emacs-w3m buffers."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-horizontal-scroll-division 4
  "*Integer used by the program making the point certainly visible.
The cursor definitely does not go missing even when it has been driven
out of the window while wandering around anchors and forms in an
emacs-w3m buffer.

Suppose that the value of this variable is N.  When the point is
outside the left of the window, emacs-w3m scrolls the window so that
the point may be displayed on the position within 1/N of the width of
the window from the left.  Similarly, when the point is outside the
right of the window, emacs-w3m scrolls the window so that the point
may be displayed on the position of 1/N of the width of the window
from the right.

This feature doesn't work if `w3m-auto-show' is nil.  The value must
be a larger integer than 1."
  :group 'w3m
  :type '(integer :size 0)
  :set (lambda (symbol value)
	 (set-default symbol (if (and (integerp value) (> value 1))
				 value
			       4))))

(defcustom w3m-show-error-information t
  "*Non-nil means show an error information as a web page.
Page is made when the foreign server doesn't respond to a request to
retrieve data."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-use-refresh t
  "*Non-nil means honor the REFRESH attribute in META tags.
Emacs-w3m arbitrarily takes you to a url specified by that attribute.
Note that they may be malicious traps."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-mbconv-command "mbconv"
  "*Name of the \"mbconv\" command provided by the \"libmoe\" package.
The \"libmoe\" package is used when you use the w3mmee command instead
of the w3m command.  See also `w3m-command'."
  :group 'w3m
  :type '(string :size 0))

(defcustom w3m-local-find-file-regexps '(nil . "\\.html?\\'")
  "*Cons of two regexps matching and not matching with local file names.
If a url of the `file:' scheme in which you entered matches the first
form and does not match the latter form, it will be opened by the
function specified by the `w3m-local-find-file-function' variable.
Nil for the regexp matches any file names.

For instance, the value `(nil . \"\\\\.html?\\\\'\")' allows
\"file:///some/where/w3m.el\", not \"file:///any/where/index.html\", to
open by the function specified by `w3m-local-find-file-function'.  The
latter will be opened as a normal web page.

It is effective only when the `w3m-local-find-file-function' variable
is set properly."
  :group 'w3m
  :type '(cons (radio :tag "Match"
		      (const :format "All " nil)
		      (regexp :format "%t: %v\n" :size 0))
	       (radio :tag "Nomatch"
		      (const :format "All " nil)
		      (regexp :format "%t: %v\n" :size 0))))

(defcustom w3m-local-find-file-function
  '(if (w3m-popup-frame-p)
       'find-file-other-frame
     'find-file-other-window)
  "*Function used to open local files.
If a url of the `file:' scheme in which you entered agrees with the
rule of the `w3m-local-find-file-regexps' variable (which see), it is
used to open the file.

Function should take one argument, the string naming the local file.
It can also be any Lisp form returning a function.  Set this to nil if
you want to always use emacs-w3m to see local files."
  :group 'w3m
  :type '(sexp :size 0))

(defcustom w3m-local-directory-view-method 'w3m-cgi
  "*Symbol of the method to view a local directory tree.
The valid values include `w3m-cgi' using the CGI program specified by
the `w3m-dirlist-cgi-program' variable (which see), and `w3m-dtree'
using the w3m-dtree Lisp module."
  :group 'w3m
  :type '(radio (const :format "Dirlist CGI  " w3m-cgi)
		(const :tag "Directory tree" w3m-dtree)))

(defcustom w3m-dirlist-cgi-program
  (cond ((eq system-type 'windows-nt)
	 "c:/usr/local/lib/w3m/dirlist.cgi")
	((memq system-type '(OS/2 emx))
	 (expand-file-name "dirlist.cmd" (getenv "W3M_LIB_DIR")))
	(t nil))
  "*Name of the CGI program to list a local directory.
If it is nil, the dirlist.cgi module of the w3m command will be used."
  :group 'w3m
  :type (` (radio
	    (const :tag "w3m internal CGI" nil)
	    (file :format "path of 'dirlist.cgi': %v\n"
		  :size 0
		  :value (, (if (not noninteractive)
				(expand-file-name
				 (concat "../lib/"
					 (file-name-nondirectory w3m-command)
					 "/dirlist.cgi")
				 (file-name-directory
				  (w3m-which-command w3m-command)))))))))

(defcustom w3m-add-referer
  (if (boundp 'w3m-add-referer-regexps)
      (symbol-value 'w3m-add-referer-regexps)
    (cons "\\`http:" "\\`http://\\(localhost\\|127\\.0\\.0\\.1\\)/"))
  "*Rule of sending referers.
There are five choices as the valid values of this option.

\(1\) nil: this means that emacs-w3m never send referers.
\(2\) t: this means that emacs-w3m always send referers.
\(3\) lambda: this means that emacs-w3m send referers only when both
    the current page and the target page are provided by the same
    server.
\(4\) a cons cell keeping two regular expressions: this means that
    emacs-w3m send referers when the url of the current page matches
    the first regular expression and does not match the second regular
    expression.  Nil for the regexp matches any url.
\(5\) a function: emacs-w3m send referers when this function which has
    two arguments, URL and REFERER, returns non-nil.

If you become nervous about leak of your private WEB browsing history,
set `nil' or `lambda' to this option.  When your computer belongs to a
secret network, you may set a pair of regular expressions to inhibit
sending referers which will disclose your private informations, as
follows:

\(setq w3m-add-referer
      '(\"\\\\`http:\"
	. \"\\\\`http://\\\\([^./]+\\\\.\\\\)*example\\\\.net/\")\)
"
  :group 'w3m
  :type '(choice
	  (const :tag "Never send referers" nil)
	  (const :tag "Always send referers" t)
	  (const :tag "Send referers when accessing the same server" lambda)
	  (cons :tag "Send referers when URI matches:"
		(list :inline t :format "%v"
		      (radio :indent 2 :sample-face underline
			     :tag "Allow"
			     (regexp :format "%t: %v\n" :size 0)
			     (const :tag "Don't allow all" nil))
		      (radio :indent 2 :sample-face underline
			     :tag "Don't allow"
			     (regexp :format "%t: %v\n" :size 0)
			     (const :tag "Allow all" nil))))
	  (function :tag "Send referers when your function returns non-nil")))

(defcustom w3m-touch-command (w3m-which-command "touch")
  "*Name of the executable file of the touch command.
Note that the command is required to be able to modify file's
timestamp with the `-t' option."
  :group 'w3m
  :type '(string :size 0))

(defcustom w3m-uri-replace-alist
  '(("\\`gg:" w3m-search-uri-replace "google")
    ("\\`ggg:" w3m-search-uri-replace "google groups")
    ("\\`ya:" w3m-search-uri-replace "yahoo")
    ("\\`al:" w3m-search-uri-replace "altavista")
    ("\\`bts:" w3m-search-uri-replace "debian-bts")
    ("\\`dpkg:" w3m-search-uri-replace "debian-pkg")
    ("\\`archie:" w3m-search-uri-replace "iij-archie")
    ("\\`urn:ietf:rfc:\\([0-9]+\\)" w3m-pattern-uri-replace
     "http://www.ietf.org/rfc/rfc\\1.txt"))
  "*Alist of regexps matching URIs, and some types of replacements.
It can be used universally to replace URI strings in the local rule to
the valid forms in the Internet.

Each element looks like the `(REGEXP FUNCTION OPTIONS...)' form.
FUNCTION takes one or more arguments, a uri and OPTIONS.  You can use
the grouping constructs \"\\\\(...\\\\)\" in REGEXP, and they can be
referred by the \"\\N\" forms in a replacement (which is one of OPTIONS).

Here are some predefined functions which can be used for those ways:

`w3m-pattern-uri-replace'
    Replace a URI using PATTERN (which is just an OPTION).  It is
    allowed that PATTERN contains the \"\\N\" forms in the same manner
    of `replace-match'.

`w3m-search-uri-replace'
    Generate the valid forms to query words to some specified search
    engines.  For example, the element

    (\"\\\\`gg:\" w3m-search-uri-replace \"google\")

    makes it possible to replace the URI \"gg:emacs\" to the form to
    query the word \"emacs\" to the Google site.\
"
  :group 'w3m
  :type '(repeat
	  (list
	   :convert-widget
	   (lambda (widget)
	     (require 'w3m-search)
	     (list
	      'choice :format "%[Value Menu%] %v" :tag "Replacing URI with"
	      :args
	      (append
	       '((list :indent 4 :tag "Replacement Using Pattern"
		       (regexp :format "%t: %v\n" :size 0)
		       (function-item :format "" w3m-pattern-uri-replace)
		       (string :format "Pattern: %v\n" :size 0)))
	       '((list :format "%t:\n%v" :indent 4 :tag "Quick Search"
		       (regexp :format "Prefix URI %t: %v\n"
			       :size 0 :value "")
		       (function-item :format "" w3m-search-uri-replace)
		       (string :format "Quick Search Engine: %v\n"
			       :size 0 :value "")))
	       (mapcar
		(lambda (elem)
		  (let ((engine (car elem))
			prefix)
		    (setq prefix (mapconcat 'identity
					    (split-string (downcase engine))
					    "-"))
		    (list 'list
			  :format "Quick Search:\n%v"
			  :tag (concat "Quick Search: " prefix)
			  (list 'regexp
				:tag "Prefix URL Regexp"
				(concat "\\`" (regexp-quote prefix) ":"))
			  '(function-item :format "" w3m-search-uri-replace)
			  (list 'string :tag "Quick Search Engine" engine))))
		w3m-search-engine-alist)
	       '((list :indent 4 :tag "User Defined Function"
		       (regexp :format "%t: %v\n" :size 0)
		       (function
			:format "%t: %v\n" :size 0
			;; Fixing a bug in Emacs versions prior to 21.4.
			:value-to-internal
			(lambda (widget value)
			  (if (stringp value)
			      (if (string-match "\\`\".*\"\\'" value)
				  (substring value 1 -1)
				value)
			    (prin1-to-string value))))
		       (repeat :extra-offset 2 :tag "Options"
			       (sexp :format "%t: %v\n" :size 0))))))))))

(defcustom w3m-relationship-estimate-rules
  `((w3m-relationship-simple-estimate
     "\\`http://\\(www\\|groups\\)\\.google\\.[^/]+/\\(search\\|groups\\)"
     ,(concat "<a href=" w3m-html-string-regexp
	      "><img src=/\\(intl/[^/]+/\\)?nav_next\\.gif")
     ,(concat "<a href=" w3m-html-string-regexp
	      "><img src=/\\(intl/[^/]+/\\)?nav_previous\\.gif")
     nil nil)
    (w3m-relationship-simple-estimate
     "\\`http://www\\.zdnet\\.co\\.jp/news/"
     ,(concat "<a href=" w3m-html-string-regexp ">$B<!$N%Z!<%8(B</a>")
     ,(concat "<a href=" w3m-html-string-regexp ">$BA0$N%Z!<%8(B</a>")
     nil nil)
    (w3m-relationship-magicpoint-estimate))
  "*Rules to estimate relationships between a retrieved page and others."
  :group 'w3m
  :type '(repeat
	  (choice
	   (group :tag "Estimate relationships from anchors matching"
		 (function :format "" w3m-relationship-simple-estimate)
		 (regexp :tag "URL")
		 (regexp :tag "Next")
		 (regexp :tag "Previous")
		 (regexp :tag "Start")
		 (regexp :tag "Contents"))
	   (list :tag "Estimate with a user defined function"
		 function
		 (repeat :tag "Arguments" sexp)))))

(defconst w3m-entity-alist
  (append
   (eval-when-compile
     (let ((basic-entity-alist
	    '(("nbsp" . " ")
	      ("gt" . ">")
	      ("lt" . "<")
	      ("amp" . "&")
	      ("quot" . "\"")
	      ("apos" . "'")
	      ("circ" . "^")
	      ("tilde" . "~")))
	   (latin1-entity
	    '(;("nbsp" . 160)
	      ("iexcl" . 161) ("cent" . 162) ("pound" . 163) ("curren" . 164)
	      ("yen" . 165) ("brvbar" . 166) ("sect" . 167) ("uml" . 168)
	      ("copy" . 169) ("ordf" . 170) ("laquo" . 171) ("not" . 172)
	      ("shy" . 173) ("reg" . 174) ("macr" . 175) ("deg" . 176)
	      ("plusmn" . 177) ("sup2" . 178) ("sup3" . 179) ("acute" . 180)
	      ("micro" . 181) ("para" . 182) ("middot" . 183) ("cedil" . 184)
	      ("sup1" . 185) ("ordm" . 186) ("raquo" . 187) ("frac14" . 188)
	      ("frac12" . 189) ("frac34" . 190) ("iquest" . 191)
	      ("Agrave" . 192) ("Aacute" . 193) ("Acirc" . 194)
	      ("Atilde" . 195) ("Auml" . 196) ("Aring" . 197) ("AElig" . 198)
	      ("Ccedil" . 199) ("Egrave" . 200) ("Eacute" . 201)
	      ("Ecirc" . 202) ("Euml" . 203) ("Igrave" . 204) ("Iacute" . 205)
	      ("Icirc" . 206) ("Iuml" . 207) ("ETH"  . 208) ("Ntilde" . 209)
	      ("Ograve" . 210) ("Oacute" . 211) ("Ocirc" . 212)
	      ("Otilde" . 213) ("Ouml" . 214) ("times" . 215) ("Oslash" . 216)
	      ("Ugrave" . 217) ("Uacute" . 218) ("Ucirc" . 219) ("Uuml" . 220)
	      ("Yacute" . 221) ("THORN" . 222) ("szlig" . 223) ("agrave" . 224)
	      ("aacute" . 225) ("acirc" . 226) ("atilde" . 227) ("auml" . 228)
	      ("aring" . 229) ("aelig" . 230) ("ccedil" . 231) ("egrave" . 232)
	      ("eacute" . 233) ("ecirc" . 234) ("euml" . 235) ("igrave" . 236)
	      ("iacute" . 237) ("icirc" . 238) ("iuml" . 239) ("eth" . 240)
	      ("ntilde" . 241) ("ograve" . 242) ("oacute" . 243)
	      ("ocirc" . 244) ("otilde" . 245) ("ouml" . 246) ("divide" . 247)
	      ("oslash" . 248) ("ugrave" . 249) ("uacute" . 250)
	      ("ucirc" . 251) ("uuml" . 252) ("yacute" . 253) ("thorn" . 254)
	      ("yuml" . 255)))
	   (greek-entity
	    '(("Alpha" . 65) ("Beta" . 66) ("Gamma" . 67) ("Delta" . 68)
	      ("Epsilon" . 69) ("Zeta" . 70) ("Eta" . 71) ("Theta" . 72)
	      ("Iota" . 73) ("Kappa" . 74) ("Lambda" . 75) ("Mu" . 76)
	      ("Nu" . 77) ("Xi" . 78) ("Omicron" . 79) ("Pi" . 80)
	      ("Rho" . 81)		; No ("Sigmaf" . 82)
	      ("Sigma" . 83) ("Tau" . 84) ("Upsilon" . 85) ("Phi" . 86)
	      ("Chi" . 87) ("Psi" . 88) ("Omega" . 89)
	      ("alpha" . 97) ("beta" . 98) ("gamma" . 99) ("delta" . 100)
	      ("epsilon" . 101) ("zeta" . 102) ("eta" . 103) ("theta" . 104)
	      ("iota" . 105) ("kappa" . 106) ("lambda" . 107) ("mu" . 108)
	      ("nu" . 109) ("xi" . 110) ("omicron" . 111) ("pi" . 112)
	      ("rho" . 113) ("sigmaf" . 114) ("sigma" . 115) ("tau" . 116)
	      ("upsilon" . 117) ("phi" . 118) ("chi" . 119) ("psi" . 120)
	      ("omega" . 121))))
       (append basic-entity-alist
	       ;; latin1
	       (mapcar
		(function
		 (lambda (entity)
		   (cons (car entity)
			 (char-to-string
			  (make-char (w3m-static-if (boundp 'MULE)
					 lc-ltn1
				       'latin-iso8859-1)
				     (cdr entity))))))
		latin1-entity)
	       ;; greek
	       (mapcar
		(function
		 (lambda (entity)
		   (cons (car entity)
			 (char-to-string
			  (make-char (w3m-static-if (boundp 'MULE)
					 lc-grk
				       'greek-iso8859-7)
				     (cdr entity))))))
		greek-entity))))
   (when (w3m-mule-unicode-p)
     (let ((latin-extended-a
	    '((32 . (("OElig" . 114) ("oelig" . 115)))
	      (33 . (("Scaron" . 32) ("scaron" . 33) ("Yuml" . 56)))))
	   (latin-extended-b '((33 . (("fnof" . 82)))))
	 ;;(spacing-modifier-letters '(36 . (("circ" . 120) ("tilde" . 124))))
	   (general-punctuation
	    '((114 .
		   (("ensp" . 98) ("emsp" . 99) ("thinsp" . 105) ("zwnj" . 108)
		    ("zwj" . 109) ("lrm" . 110) ("rlm" . 111) ("ndash" . 115)
		    ("mdash" . 116) ("lsquo" . 120) ("rsquo" . 121)
		    ("sbquo" . 122) ("ldquo" . 124) ("rdquo" . 125)
		    ("bdquo" . 126)))
	      (115 .
		   (("dagger" . 32) ("Dagger" . 33) ("permil" . 48)
		    ("lsaquo" . 57) ("rsaquo" . 58)
		    ("bull" . 34) ("hellip" . 38) ("prime" . 50) ("Prime" . 51)
		    ("oline" . 62) ("frasl" . 68)))
	      (116 .
		   (("euro" . 76)))))
	   (greek '((39 . (("thetasym" . 81) ("upsih" . 82) ("piv" . 86)))))
	   (letterlike-symbols
	    '((117 .
		   (("weierp" . 88) ("image" . 81) ("real" . 92)
		    ("trade" . 98) ("alefsym" . 117)))))
	   (arrows
	    '((118 .
		   (("larr" . 112) ("uarr" . 113) ("rarr" . 114) ("darr" . 115)
		    ("harr" . 116)))
	      (119 .
		   (("crarr" . 53) ("lArr" . 80) ("uArr" . 81) ("rArr" . 81)
		    ("dArr" . 83) ("hArr" . 84)))))
	   (mathematical-operators
	    '((120 .
		   (("forall" . 32) ("part" . 34) ("exist" . 35) ("empty" . 37)
		    ("nabla" . 39) ("isin" . 40) ("notin" . 41) ("ni" . 43)
		    ("prod" . 47) ("sum" . 49) ("minus" . 50) ("lowast" . 55)
		    ("radic" . 58) ("prop" . 61) ("infin" . 62) ("ang" . 64)
		    ("and" . 71) ("or" . 72) ("cap" . 73) ("cup" . 74)
		    ("int" . 75) ("there4" . 84) ("sim" . 92) ("cong" . 101)
		    ("asymp" . 104)))
	      (121 .
		   (("ne" . 32) ("equiv" . 33) ("le" . 36) ("ge" . 37)
		    ("sub" . 66) ("sup" . 67) ("nsub" . 68) ("sube" . 70)
		    ("supe" . 71) ("oplus" . 85) ("otimes" . 87)
		    ("perp" . 101)))
	      (122 . (("sdot" . 37)))))
	   (miscellaneous-technical
	    '((122 . (("lceil" . 104) ("rceil" . 105) ("lfloor" . 106)
		      ("rfloor" . 107)))
	      (123 . (("lang" . 41) ("rang" . 42)))))
	   (suit
	    '(("loz" . (34 . 42)) ("spades" . (35 . 96)) ("clubs" . (35 . 99))
	      ("hearts" . (35 . 101)) ("diams" . (35 . 102)))))
       (append
	(apply 'append
	       (mapcar
		(function
		 (lambda (entities)
		   (let ((code1 (car entities)))
		     (mapcar
		      (lambda (entity)
			(cons (car entity)
			      (char-to-string
			       (make-char 'mule-unicode-0100-24ff
					  code1 (cdr entity)))))
		      (cdr entities)))))
		`(,@latin-extended-a ,@latin-extended-b ,@general-punctuation
		  ,@greek ,@letterlike-symbols ,@arrows
		  ,@mathematical-operators ,@miscellaneous-technical)))
	(mapcar
	 (function
	  (lambda (entity)
	    (cons (car entity)
		  (char-to-string
		   (make-char 'mule-unicode-2500-33ff
			      (car (cdr entity)) (cdr (cdr entity)))))))
	 suit)))))
  "Alist of html character entities and values.")

(defconst w3m-entity-regexp
  "&\\([a-z][a-z0-9]*\\|#[0-9]+\\|#x[0-9a-f]+\\)\\(;\\)?"
  "Regexp matching html character entities.")

(defvar w3m-entity-db nil
  "Hash table of `w3m-entity-alist'.
The nil value means it has not been initialized.")

(defconst w3m-entity-db-size 13 "Size of `w3m-entity-db'.")

(defconst w3m-encoding-alist
  (eval-when-compile
    (apply 'nconc
	   (mapcar (lambda (elem)
		     (mapcar (lambda (x) (cons x (car elem)))
			     (cdr elem)))
		   '((gzip . ("gzip" "x-gzip" "compress" "x-compress"))
		     (bzip . ("x-bzip" "bzip" "bzip2"))
		     (deflate . ("x-deflate" "deflate"))))))
  "Alist of content encoding types and decoder symbols.
Decoders are specified by `w3m-decoder-alist' (which see).")

(defconst w3m-emacs-w3m-icon "\
R0lGODlhUwAOAPIFAP///38AvwAAv1Uq/AC/AL9/Af8AAAAAACH/C05FVFNDQVBFMi4wAwEA
AAAh+QQEIQD/ACwAAAAAUwAOAEADwgi63P4wykldCBYDIRT33RYOQ0ScU1EAKrs2hqHEswzQ
ynUte78vnA9DQGKQihIUQNliNGlQXGVKrVqv2Oy06Zr+vpqfcDgqAZDHCvPVVHFxcJsOAAbZ
RWdkfn9GKSVtbC83NnE1WoiIblyJjY4KXIwSdXQ+GEKYIXtoZnoPa5CDoTUyMaVyOpRimkFC
ngtHZksntAQKBCstkiyFvYeVGXeZCpzEsgt/EYGjv4aEPHPCIWNEJXppyLQVy6RSzlKP4eIJ
ACH5BAQhAP8ALAAAAAABAAEAAAMCCAkAIfkEBCEA/wAsAQABAFEACwAAAx0Iutz+MMpJq704
6827/2AojmRpnmiqrmzrvnBsJgAh+QQEIQD/ACwBAAQAEQAIAAADHAixAb6qMRgfZDbXHaem
nBOKINmIpnSWqIe+TgIAIfkEBCEA/wAsCQAEABcACAAAAykYAcoNUEgBq1ALAxnp9tXzcFVX
OtAITmS4fCYsuzHZnqhsg/geb7hKAgAh+QQEIQD/ACwXAAQAFAAIAAADJSgKzDKjAQjbYrXO
uJ3AnEZZytdJoAZcKuqKIeduchaidjPOQAIAIfkEBCEA/wAsJgAEABUACAAAAyA4OtD+gJAm
GVAQyodz3s5iRVI5RR/ordTJapP6OuacJQAh+QQEIQD/ACw2AAEAEAALAAADJgi6XO4sAqio
nGU5ogjH0VZlYFN8VPoARAZZGviSlzpKdmneF5AAADs="
  "A small image to be displayed in the about: page.
It is encoded in the optimized interlaced endlessly animated gif format
and base64.  Emacs can display only the 1st frame of an animation, but
XEmacs can fully display it with the help of the gifsicle program.")

(defcustom w3m-process-modeline-format " loaded: %s"
  "*Format used when displaying the progress of the external w3m process.
It shows a percentage of the data loaded from the web server."
  :group 'w3m
  :type '(choice (string :tag "Format") function))

(defvar w3m-modeline-process-status-on "<PRC>"
  "Modeline control for displaying the status when the process is running.
The value will be modified for displaying the graphic icon.")

(defvar w3m-modeline-image-status-on "[IMG]"
  "Modeline control to display the status when inline images are turned on.
The value will be modified for displaying the graphic icon.")

(defvar w3m-modeline-status-off "[ - ]"
  "Modeline control for displaying the status for the default.
The value will be modified for displaying the graphic icon.")

(defvar w3m-modeline-ssl-image-status-on "[IMG(SSL)]"
  "Modeline control for displaying the status when images and SSL are on.
The value will be modified for displaying the graphic icon.")

(defvar w3m-modeline-ssl-status-off "[SSL]"
  "Modeline control for displaying the status when SSL is turned on.
The value will be modified for displaying the graphic icon.")

(defvar w3m-modeline-separator " / "
  "String used to separate a status and a title in the modeline.")

(defvar w3m-modeline-favicon nil
  "Modeline control for displaying a favicon.
This variable will be made buffer-local under Emacs 21 or XEmacs.")

(defvar w3m-favicon-image nil
  "Favicon image of the page.
This variable will be made buffer-local under Emacs 21 or XEmacs.")

(defvar w3m-current-process nil
  "Flag used to say whether the external process is running in the buffer.
This variable will be made buffer-local.")
(make-variable-buffer-local 'w3m-current-process)

(defvar w3m-refresh-timer nil
  "Variable used to keep a timer object for refreshing a page.
It will be supplied by the REFRESH attribute in the META tag, and made
buffer-local in each emacs-w3m buffer.")
(make-variable-buffer-local 'w3m-refresh-timer)

(defvar w3m-current-base-url nil
  "URL specified by <base...> tag in <head> element of the page source.")
(defvar w3m-current-forms nil
  "Variable used to keep forms data for the current emacs-w3m buffer.")
(defvar w3m-current-coding-system nil
  "Coding system used when decoding the current emacs-w3m buffer.")
(defvar w3m-current-content-charset nil
  "Content charset of the page specified by the server or the META tag.")
(defvar w3m-icon-data nil
  "Cons of icon data and its image-type for the current emacs-w3m buffer.
It is used for favicon data.  The type is often `ico'.")
(defvar w3m-next-url nil
  "URL as the next document in the author-defined sequence.")
(defvar w3m-previous-url nil
  "URL as the previous document in the author-defined sequence.")
(defvar w3m-start-url nil
  "URL as the first document in the author-defined sequence.")
(defvar w3m-contents-url nil
  "URL as the table of contents for the current page.")
(defvar w3m-max-anchor-sequence nil
  "Maximum number of the anchor sequence in the current page.")
(defvar w3m-current-refresh nil
  "Cons of number of seconds and a url specified by the REFRESH attribute.")
(defvar w3m-current-ssl nil
  "SSL certification indicator for the current emacs-w3m buffer.")

(make-variable-buffer-local 'w3m-current-url)
(make-variable-buffer-local 'w3m-current-base-url)
(make-variable-buffer-local 'w3m-current-title)
(make-variable-buffer-local 'w3m-current-forms)
(make-variable-buffer-local 'w3m-current-coding-system)
(make-variable-buffer-local 'w3m-current-content-charset)
(make-variable-buffer-local 'w3m-icon-data)
(make-variable-buffer-local 'w3m-next-url)
(make-variable-buffer-local 'w3m-previous-url)
(make-variable-buffer-local 'w3m-start-url)
(make-variable-buffer-local 'w3m-contents-url)
(make-variable-buffer-local 'w3m-max-anchor-sequence)
(make-variable-buffer-local 'w3m-current-refresh)
(make-variable-buffer-local 'w3m-current-ssl)

(defsubst w3m-clear-local-variables ()
  (setq w3m-current-url nil
	w3m-current-base-url nil
	w3m-current-title nil
	w3m-current-coding-system nil
	w3m-current-content-charset nil
	w3m-icon-data nil
	w3m-next-url nil
	w3m-previous-url nil
	w3m-start-url nil
	w3m-contents-url nil
	w3m-max-anchor-sequence nil
	w3m-current-refresh nil
	w3m-current-ssl nil))

(defsubst w3m-copy-local-variables (from-buffer)
  (let (url base title cs char icon next prev start toc hseq refresh ssl)
    (with-current-buffer from-buffer
      (setq url w3m-current-url
	    base w3m-current-base-url
	    title w3m-current-title
	    cs w3m-current-coding-system
	    char w3m-current-content-charset
	    icon w3m-icon-data
	    next w3m-next-url
	    prev w3m-previous-url
	    start w3m-start-url
	    toc w3m-contents-url
	    hseq w3m-max-anchor-sequence
	    refresh w3m-current-refresh
	    ssl w3m-current-ssl))
    (setq w3m-current-url url
	  w3m-current-base-url base
	  w3m-current-title title
	  w3m-current-coding-system cs
	  w3m-current-content-charset char
	  w3m-icon-data icon
	  w3m-next-url next
	  w3m-previous-url prev
	  w3m-start-url start
	  w3m-contents-url toc
	  w3m-max-anchor-sequence hseq
	  w3m-current-refresh refresh
	  w3m-current-ssl ssl)))

(defvar w3m-verbose nil
  "*Flag controls whether emacs-w3m should be verbose.")

(defvar w3m-safe-url-regexp nil
  "Regexp matching urls which are considered to be safe.")

(defvar w3m-current-buffer nil)
(defvar w3m-cache-buffer nil)
(defvar w3m-cache-articles nil)
(defvar w3m-cache-hashtb nil)
(defvar w3m-input-url-history nil)

(defconst w3m-arrived-db-size 1023)
(defvar w3m-arrived-db nil
  "Hash table, the arrived URLs database.
The name of each symbol represents a url, the arrival time in the
Emacs style (a list of three integers) is stored as the value, and
informations including a title, a modification time, a content charset
and a content type are stored as the properties of the symbol.  The
nil value means it has not been initialized.")

(defvar w3m-arrived-setup-functions nil
  "Hook functions run after setting up the arrived URLs database.")
(defvar w3m-arrived-shutdown-functions nil
  "Hook functions run after saving the arrived URLs database.")

(defconst w3m-image-type-alist
  '(("image/jpeg" . jpeg)
    ("image/gif" . gif)
    ("image/png" . png)
    ("image/x-xbm" . xbm)
    ("image/x-xpm" . xpm))
  "Alist of content types and image types defined as the Emacs' features.")

(defconst w3m-toolbar-buttons
  '("back" "parent" "forward" "reload" "open" "home" "search" "image"
    "copy" "weather" "antenna" "history" "db-history")
  "List of prefix strings for the toolbar buttons.")

(defconst w3m-toolbar
  (if (equal "Japanese" w3m-language)
      (let ((a (decode-coding-string "\e$B%\"\e(B" 'iso-2022-jp)));;$B%"(B
	`([w3m-toolbar-back-icon w3m-view-previous-page
				 (w3m-history-previous-link-available-p)
				 "$BA0$N%Z!<%8$KLa$k(B"]
	  [w3m-toolbar-parent-icon w3m-view-parent-page
				   (w3m-parent-page-available-p)
				   "$B>e$N%G%#%l%/%H%j$X0\F0$9$k(B"]
	  [w3m-toolbar-forward-icon w3m-view-next-page
				    (w3m-history-next-link-available-p)
				    "$B<!$N%Z!<%8$K?J$`(B"]
	  [w3m-toolbar-reload-icon w3m-reload-this-page
				   w3m-current-url
				   "$B%5!<%P$+$i%Z!<%8$r$b$&0lEYFI$_9~$`(B"]
	  [w3m-toolbar-open-icon w3m-goto-url t "URL $B$rF~NO$7$F%Z!<%8$r3+$/(B"]
	  [w3m-toolbar-home-icon w3m-gohome w3m-home-page
				 "$B%[!<%`%Z!<%8$X%8%c%s%W(B"]
	  [w3m-toolbar-search-icon w3m-search t "$B%$%s%?!<%M%C%H>e$r8!:w(B"]
	  [w3m-toolbar-image-icon w3m-toggle-inline-images t
				  "$B2hA|$NI=<($r%H%0%k$9$k(B"]
	  [w3m-toolbar-copy-icon w3m-copy-buffer t
				 "$B$3$N%;%C%7%g%s$N%3%T!<$r:n$k(B"]
	  [w3m-toolbar-weather-icon w3m-weather t "$BE75$M=Js$r8+$k(B"]
	  [w3m-toolbar-antenna-icon w3m-antenna t
				    ,(concat a "$B%s%F%J$G<u?.$9$k(B")]
	  [w3m-toolbar-history-icon w3m-history t "$B%R%9%H%j!<(B"]
	  [w3m-toolbar-db-history-icon w3m-db-history t
				       "$B2a5n$KK,Ld$7$?(B URL $B$NMzNr$r8+$k(B"]))
    '([w3m-toolbar-back-icon w3m-view-previous-page
			     (w3m-history-previous-link-available-p)
			     "Back to Previous Page"]
      [w3m-toolbar-parent-icon w3m-view-parent-page
			       (w3m-parent-page-available-p)
			       "View the parent page"]
      [w3m-toolbar-forward-icon w3m-view-next-page
				(w3m-history-next-link-available-p)
				"Forward to Next Page"]
      [w3m-toolbar-reload-icon w3m-reload-this-page
			       w3m-current-url
			       "Reload This Page"]
      [w3m-toolbar-open-icon w3m-goto-url t "Go to..."]
      [w3m-toolbar-home-icon w3m-gohome w3m-home-page "Go to Home Page"]
      [w3m-toolbar-search-icon w3m-search t "Search the Internet"]
      [w3m-toolbar-image-icon w3m-toggle-inline-images t "Toggle Images"]
      [w3m-toolbar-copy-icon w3m-copy-buffer t "Make a Copy of This Session"]
      [w3m-toolbar-weather-icon w3m-weather t "Weather Forecast"]
      [w3m-toolbar-antenna-icon w3m-antenna t "Investigate with Antenna"]
      [w3m-toolbar-history-icon w3m-history t "Show a History"]
      [w3m-toolbar-db-history-icon w3m-db-history t "View Arrived URLs"]))
  "Toolbar definition for emacs-w3m.")

(defconst w3m-menubar
  '("W3M"
    ["Go to Home Page" w3m-gohome w3m-home-page]
    ["Back to Previous Page" w3m-view-previous-page
     (w3m-history-previous-link-available-p)]
    ["Forward to Next Page" w3m-view-next-page
     (w3m-history-next-link-available-p)]
    ["View the parent page" w3m-view-parent-page
     (w3m-parent-page-available-p)]
    ;;
    ["Reload This Page" w3m-reload-this-page w3m-current-url]
    ["Cancel Process" w3m-process-stop t]
    ["Toggle Images" w3m-toggle-inline-images (w3m-display-graphic-p)]
    ;;
    ["Redisplay This Page" w3m-redisplay-this-page w3m-current-url]
    ["Redisplay This Page with Charset"
     w3m-redisplay-with-charset w3m-current-url]
    ["Redisplay This Page with Content-type"
     w3m-redisplay-with-content-type w3m-current-url]
    ["Reset Charset and Content-type" w3m-redisplay-and-reset w3m-current-url]
    ;;
    ["Go to..." w3m-goto-url t]
    ["Go to... in the New Session" w3m-goto-url-new-session t]
    ["Make a Copy of This Session" w3m-copy-buffer t]
    ;;
    ["View Bookmark" w3m-bookmark-view t]
    ["Search the Internet" w3m-search t]
    ["Weather Forecast" w3m-weather t]
    ["Investigate with Antenna" w3m-antenna t]
    ;;
    ["View Source" w3m-view-source t]
    ["View Header" w3m-view-header t]
    ["Show a History" w3m-history t]
    ["View Arrived URLs" w3m-db-history t]
    ;;
    ["Download This URL" w3m-download-this-url t]
    ["Print the Current URL" w3m-print-current-url t]
    ;;
    ["Send a Bug Report" report-emacs-w3m-bug t]
    )
  "Menubar definition for emacs-w3m.")

(defvar w3m-cid-retrieve-function-alist nil)
(defvar w3m-force-redisplay t)

(defvar w3m-work-buffer-list nil)
(defconst w3m-work-buffer-name " *w3m-work*")
(defconst w3m-select-buffer-name " *w3m buffers*")

(defconst w3m-dump-head-source-command-arguments
  (cond ((eq w3m-type 'w3mmee)
	 (list "-dump=extra,head,source"))
	(t
	 (list
	  '(if w3m-accept-languages
	       '("-o"
		 (concat "accept_language="
			 (mapconcat 'identity w3m-accept-languages ","))))
	  "-dump_extra")))
  "Arguments passed to the w3m command to run \"dump_extra\".")

(defvar w3m-halfdump-command nil
  "Alternative w3m command used to run \"halfdump\".
If it is nil, the command specified to `w3m-command' is used.")

(defconst w3m-halfdump-command-arguments
  (cond ((eq w3m-type 'w3mmee)
	 (list '(if w3m-treat-image-size
		    "-dump=half-buffer,single-row-image"
		  "-dump=half-buffer")
	       '(if (eq w3m-input-coding-system 'ctext)
		    (list "-I" "x-ctext")
		  (when (and (eq w3m-input-coding-system 'binary)
			     charset)
		    (list "-I" 'charset)))
	       "-o" "concurrent=0"))
	((eq w3m-type 'w3m-m17n)
	 (list "-halfdump"
	       "-o" "ext_halfdump=1"
	       "-o" "strict_iso2022=0"
	       "-o" "ucs_conv=1"
	       '(if (eq w3m-input-coding-system 'binary)
		    (if charset (list "-I" 'charset))
		  (list "-I" (if (eq w3m-input-coding-system 'utf-8)
				 "UTF-8"
			       "ISO-2022-JP-2")))
	       "-O"
	       '(if (eq w3m-output-coding-system 'utf-8)
		    "UTF-8"
		  "ISO-2022-JP-2")))
	((eq w3m-input-coding-system 'w3m-euc-japan)
	 (list "-halfdump" "-I" "e"))
	(t (list "-halfdump")))
  "Arguments passed to the w3m command to run \"halfdump\".")

(defconst w3m-halfdump-command-common-arguments
  '("-T" "text/html" "-t" tab-width "-cols" (w3m-display-width))
  "Arguments used in common by the w3m command variants to run \"halfdump\".")

(defconst w3m-arrived-ignored-regexp
  "\\`about:\\(//\\(header\\|source\\|history\\|\
db-history\\|antenna\\|namazu\\|dtree\\)/.*\\)?\\'\
\\|\\`about:/*blank/?\\'"
  "Regexp matching urls which aren't stored in the arrived URLs database.")

(defconst w3m-history-ignored-regexp
  "\\`about:\\(//\\(header\\|source\\|history\\|\
db-history\\|antenna\\|namazu\\|dtree\\)/.*\\)?\\'\
\\|\\`about:/*blank/?\\'"
  "Regexp matching urls which aren't stored in the history.")

(defconst w3m-url-components-regexp
  "\\`\\(\\([^:/?#]+\\):\\)?\\(//\\([^/?#]*\\)\\)?\
\\([^?#]*\\)\\(\\?\\([^#]*\\)\\)?\\(#\\(.*\\)\\)?\\'"
  "Regexp used for parsing a URI Reference.
It matches the potential four components and fragment identifier of a
URI reference.  See RFC2396, Appendix B for details.")

(defvar w3m-mode-map nil "Keymap for emacs-w3m buffers.")

(defvar w3m-mode-setup-functions nil
  "Hook functions run after setting up the `w3m-mode'.")
(defvar w3m-display-functions nil
  "Hook functions run after displaying pages in emacs-w3m buffers.
Each function is called with a url string as the argument.  This hook
is evaluated just before evaluating `w3m-display-hook'.")

(defvar w3m-load-hook nil
  "*Hook run after loading the w3m.elc module.
It is not recommended that you use this hook instead of writing into
`w3m-init-file' for customization.")


;; Generic functions:
(defun w3m-url-to-file-name (url)
  "Return the file name which is pointed to by URL.
When URL does not point to any local files, it returns nil.  The
actual performance of this function is to strip off the scheme part
and the net_loc part from URL.  It is meaningless to give an argument
whose net_loc part is not empty, a null string or the localhost name
to this function."
  (cond
   ((string-match "\\`\\(\\(file:\\(//\\)?\\)\\|about://dtree\\)/" url)
    (setq url (substring url (match-end 1)))
    ;; Strip the localhost name.
    (when (and (match-beginning 2) ;; file:
	       (string-match (concat "\\`//\\(localhost\\|127\\.0\\.0\\.1\\|"
				     (regexp-quote (system-name)) "\\)/")
			     url))
      (setq url (substring url (match-end 1))))
    ;; Process abs_path part in Windows.
    (setq url
	  (if (and w3m-treat-drive-letter
		   (string-match
		    "\\`/\\(\\([a-zA-Z]\\)[|:]?\\|cygdrive/\\([a-zA-Z]\\)\\)/"
		    url))
	      (concat (or (match-string 2 url) (match-string 3 url))
		      ":/"
		      (substring url (match-end 0)))
	    url))
    (if (file-exists-p url)
	url
      (let ((x (w3m-url-decode-string url w3m-file-name-coding-system)))
	(if (file-exists-p x) x url))))
   ((string-match "\\`\\([~/]\\|[a-zA-Z]:/\\|\\.\\.?/\\)" url) url)
   (t
    (catch 'found-file
      (dolist (pair w3m-url-local-directory-alist)
	(and (string-match (concat "\\`"
				   (regexp-quote
				    (file-name-as-directory (car pair))))
			   url)
	     (let ((file (expand-file-name (substring url (match-end 0))
					   (cdr pair))))
	       (when (or (file-exists-p file)
			 (file-exists-p
			  (setq file (w3m-url-decode-string
				      file w3m-file-name-coding-system))))
		 (throw 'found-file file)))))))))

(defun w3m-expand-file-name-as-url (file &optional directory)
  "Return a url string which points to the FILE.
Optional DIRECTORY is a directory to start with if FILE is relative
\(i.e., FILE doesn't start with slash).  It defaults to the current
directory."
  (setq file (expand-file-name file directory))
  (concat "file://"
	  (if (string-match "\\`\\([a-zA-Z]\\):" file)
	      (format (if w3m-use-cygdrive "/cygdrive/%s%s" "/%s|%s")
		      (match-string 1 file)
		      (substring file (match-end 0)))
	    file)))


;;; Managing the arrived URLs database:
(defun w3m-arrived-add (url &optional title modification-time
			    arrival-time content-charset content-type)
  "Add URL to the arrived URLs database.
Optional TITLE, MODIFICATION-TIME, ARRIVAL-TIME, CONTENT-CHARSET and
CONTENT-TYPE are also be added."
  (unless (string-match w3m-arrived-ignored-regexp url)
    (let ((ident (intern url w3m-arrived-db)))
      (if (string-match "\\`\\([^#]+\\)#" url)
	  (w3m-arrived-add (substring url 0 (match-end 1))
			   title modification-time arrival-time
			   content-charset content-type)
	(when title
	  (put ident 'title title))
	(when modification-time
	  (put ident 'last-modified modification-time))
	(when content-charset
	  (put ident 'content-charset content-charset))
	(when content-type
	  (put ident 'content-type content-type)))
      (set ident arrival-time))))

(defsubst w3m-arrived-p (url)
  "Return non-nil if a page of URL has arrived."
  (or (string-match w3m-arrived-ignored-regexp url)
      (intern-soft url w3m-arrived-db)))

(defun w3m-arrived-time (url)
  "Return the arrival time of a page of URL if it has arrived.
Otherwise return nil."
  (let ((v (intern-soft url w3m-arrived-db)))
    (and v (boundp v) (symbol-value v))))
(defsetf w3m-arrived-time (url) (value)
  (list 'w3m-arrived-add url nil nil value))

(defsubst w3m-arrived-put (url property value)
  "Store VALUE in the arrived URLs database as the PROPERTY of URL.
Return VALUE if a page of URL has arrived.  Otherwise, VALUE is
ignored and return nil."
  (let ((symbol (intern-soft url w3m-arrived-db)))
    (and symbol (put symbol property value))))

(defsubst w3m-arrived-get (url property)
  "Return the value of URL's PROPERTY stored in the arrived URLs database.
If a page of URL has not arrived, return nil."
  (let ((symbol (intern-soft url w3m-arrived-db)))
    (and symbol (get symbol property))))

(defsetf w3m-arrived-get w3m-arrived-put)

(defmacro w3m-arrived-title (url)
  "Return the title of URL having stored in the arrived URLs database."
  `(w3m-arrived-get ,url 'title))

(defmacro w3m-arrived-last-modified (url)
  "Return the mod time of URL having stored in the arrived URLs database.
If a page of URL has not arrived yet, return nil."
  `(w3m-arrived-get ,url 'last-modified))

(defmacro w3m-arrived-content-charset (url)
  "Return the content charset of URL stored in the arrived URLs database.
If it has not been specified or a page of URL has not arrived yet,
return nil."
  `(w3m-arrived-get ,url 'content-charset))

(defmacro w3m-arrived-content-type (url)
  "Return the content type of URL stored in the arrived URLs database.
If it has not been specified or a page of URL has not arrived yet,
return nil."
  `(w3m-arrived-get ,url 'content-type))

(defun w3m-arrived-load-list ()
  "Load the arrived URLs database file.
The file is specified by `w3m-arrived-file'.  If the data is in old
format, they will simply be ignored."
  (let ((list (w3m-load-list w3m-arrived-file)))
    (when (or
	   ;; Before the revision 1.120, every element of the list was
	   ;; a string that represented an arrived URL.
	   (stringp (car list))
	   ;; Before the revision 1.135, every element was a cons
	   ;; cell: its car kept a URL, and its cdr kept a time when
	   ;; the URL was arrived.
	   ;; Before the revision 1.178, every element was a 4-tuple
	   ;; that consisted of a URL, a title, a modification time,
	   ;; and an arrival time.
	   ;; An element of the modern database is a 6-tuple that
	   ;; consisted of a URL, a title, a modification time, an
	   ;; arrival time, a charset, and a content type.
	   ;; Thus, the following condition eliminates the revision
	   ;; 1.177 and olders.
	   (<= (length (car list)) 4))
      (setq list nil)
      (when (file-exists-p w3m-arrived-file)
	(delete-file w3m-arrived-file)))
    list))

(defun w3m-arrived-setup ()
  "Load the arrived URLs database file and set up the hashed database.
It is performed only when `w3m-arrived-db' has not been initialize yet.
The file is specified by `w3m-arrived-file'."
  (unless w3m-arrived-db
    (setq w3m-arrived-db (make-vector w3m-arrived-db-size 0))
    (let ((list (w3m-arrived-load-list)))
      (dolist (elem list)
	;; Ignore an element that lacks an arrival time information.
	(when (nth 3 elem)
	  (w3m-arrived-add (if (string-match "\\`/" (car elem))
			       (w3m-expand-file-name-as-url (car elem))
			     (car elem))
			   (nth 1 elem)
			   (nth 2 elem)
			   (nth 3 elem)
			   (when (stringp (nth 4 elem)) (nth 4 elem))
			   (nth 5 elem))))
      (unless w3m-input-url-history
	(setq w3m-input-url-history (mapcar (function car) list))))
    (run-hooks 'w3m-arrived-setup-functions)))

(defun w3m-arrived-shutdown ()
  "Save the arrived URLs database in the file.
The database `w3m-arrived-db' will be cleared after saving.  The file
is specified by `w3m-arrived-file'."
  (when w3m-arrived-db
    ;; Re-read the database file, and if there are data which another
    ;; Emacs process registered, merge them to the current database.
    (dolist (elem (w3m-arrived-load-list))
      (when (w3m-time-newer-p (nth 3 elem) (w3m-arrived-time (car elem)))
	(w3m-arrived-add (if (string-match "\\`/" (car elem))
			     (w3m-expand-file-name-as-url (car elem))
			   (car elem))
			 (nth 1 elem)
			 (nth 2 elem)
			 (nth 3 elem)
			 (when (stringp (nth 4 elem)) (nth 4 elem))
			 (nth 5 elem))))
    ;; Convert current database to a list.
    (let (list)
      (mapatoms
       (lambda (sym)
	 (and sym
	      (boundp sym)
	      (symbol-value sym) ; Ignore an entry lacks an arrival time.
	      (push (list (symbol-name sym)
			  (get sym 'title)
			  (get sym 'last-modified)
			  (symbol-value sym)
			  (get sym 'content-charset)
			  (get sym 'content-type))
		    list)))
       w3m-arrived-db)
      (w3m-save-list w3m-arrived-file
		     (w3m-sub-list
		      (sort list
			    (lambda (a b)
			      (if (equal (nth 3 a) (nth 3 b))
				  (string< (car a) (car b))
				(w3m-time-newer-p (nth 3 a) (nth 3 b)))))
		      w3m-keep-arrived-urls)
		     nil t))
    (setq w3m-arrived-db nil)
    (run-hooks 'w3m-arrived-shutdown-functions)))

(add-hook 'kill-emacs-hook 'w3m-arrived-shutdown)


;;; Generic macros and inline functions:
(defun w3m-attributes (url &optional no-cache handler)
  "Return a list of attributes corresponding to URL.
Return nil if it failed in retrieving of the header.
Otherwise, return a list which includes the following elements:

 0. Type of contents.
 1. Charset of contents.
 2. Size in bytes.
 3. Encoding of contents.
 4. Last modification time.
 5. Real URL.

If the optional argument NO-CACHE is non-nil, cache is not used."
  (if (not handler)
      (condition-case nil
	  (w3m-process-with-wait-handler
	    (w3m-attributes url no-cache handler))
	(w3m-process-timeout nil))
    (setq url (w3m-url-strip-fragment url))
    (cond
     ((string= "about://emacs-w3m.gif" url)
      (list "image/gif" nil nil nil nil url url))
     ((string-match "\\`about://source/" url)
      (lexical-let ((src (substring url (match-end 0))))
	(w3m-process-do
	    (attrs (w3m-attributes src no-cache handler))
	  (list "text/plain"
		(or (w3m-arrived-content-charset (w3m-url-strip-authinfo src))
		    (cadr attrs))
		(nth 2 attrs)
		(nth 3 attrs)
		(nth 4 attrs)
		(concat "about://source/" (nth 5 attrs))))))
     ((string-match "\\`about:" url)
      (list "text/html" w3m-coding-system nil nil nil url))
     ((w3m-url-local-p url)
      (w3m-local-attributes url))
     (t
      (w3m-w3m-attributes url no-cache handler)))))

(defmacro w3m-content-type (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (car attrs)))
    `(car (w3m-attributes ,url ,no-cache))))
(defmacro w3m-content-charset (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (nth 1 attrs)))
    `(nth 1 (w3m-attributes ,url ,no-cache))))
(defmacro w3m-content-length (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (nth 2 attrs)))
    `(nth 2 (w3m-attributes ,url ,no-cache))))
(defmacro w3m-content-encoding (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (nth 3 attrs)))
    `(nth 3 (w3m-attributes ,url ,no-cache))))
(defmacro w3m-last-modified (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (nth 4 attrs)))
    `(nth 4 (w3m-attributes ,url ,no-cache))))
(defmacro w3m-real-url (url &optional no-cache handler)
  (if handler
      `(let ((handler ,handler))
	 (w3m-process-do
	     (attrs (w3m-attributes ,url ,no-cache handler))
	   (nth 5 attrs)))
    `(nth 5 (w3m-attributes ,url ,no-cache))))

(defmacro w3m-make-help-echo (property)
  "Make a function returning a string used for the `help-echo' message.
PROPERTY is a symbol (which doesn't need to be quoted) of a text
property (in XEmacs, it is an extent) with the value of a string which
should be in the place where having to show a help message.  If you
need to know what function will be made, use `macroexpand'."
  (if (featurep 'xemacs)
      `(if (>= emacs-major-version 21)
	   (function
	    (lambda (extent)
	      (if (and w3m-track-mouse
		       (eq (extent-object extent) (current-buffer)))
		  (get-text-property (extent-start-position extent)
				     ',property)))))
    `(if (>= emacs-major-version 21)
	 (function
	  (lambda (window object pos)
	    (if w3m-track-mouse
		(progn
		  (w3m-message "")	; Clear the echo area.
		  (get-text-property pos ',property
				     (window-buffer window)))))))))

(defmacro w3m-make-balloon-help (property)
  "Make a function returning a string used for the `balloon-help' message.
Functions made are used only when emacs-w3m is running under XEmacs.
It returns an interned symbol of a function.  PROPERTY is a symbol
\(which doesn't need to be quoted) of an extent with the value of a
string which should be in the place where having to show a help
message."
  (when (featurep 'xemacs)
    `(let ((fn (intern (format "w3m-balloon-help-for-%s"
			       ',property))))
       (prog1
	   fn
	 (unless (fboundp fn)
	   (defalias fn
	     (lambda (extent)
	       (if (and w3m-track-mouse
			(eq (extent-object extent) (current-buffer)))
		   (get-text-property (extent-start-position extent)
				      ',property)))))
	 (when (and (featurep 'bytecomp)
		    (not (compiled-function-p (symbol-function fn))))
	   (byte-compile fn))))))

(defun w3m-message (&rest args)
  "Print a one-line message at the bottom of the screen.
It displays a given message without logging, when the cursor is not in
the minibuffer and `w3m-verbose' is nil.  When the cursor is in the
minibuffer and `w3m-verbose' is nil, it behaves as `format' and simply
returns a string.  When `w3m-verbose' is non-nil, it behaves
identically as `message', that displays a given message with logging."
  (if w3m-verbose
      (apply (function message) args)
    (if (eq (selected-window) (minibuffer-window))
	(apply (function format) args)
      (w3m-static-if (featurep 'xemacs)
	  (display-message 'no-log (apply (function format) args))
	(let (message-log-max)
	  (apply (function message) args))))))

(defun w3m-time-parse-string (string)
  "Parse the time-string STRING into a time in the Emacs style."
  (ignore-errors
    (let ((x (timezone-fix-time string nil nil)))
      (encode-time (aref x 5) (aref x 4) (aref x 3)
		   (aref x 2) (aref x 1) (aref x 0)
		   (aref x 6)))))

;; When a buggy timezone.el is loaded, we use parse-time.el instead.
(unless (equal (w3m-time-parse-string "Thursday, 01-Jan-1970 00:00:00 GMT")
	       '(0 0))
  (ignore-errors
    (require 'parse-time))
  (defun w3m-time-parse-string (string)
    "Parse the time-string STRING and return its time as Emacs style."
    (ignore-errors
      (let ((fn (when (fboundp 'parse-time-string)
		  'parse-time-string)))
	(when fn
	  (apply (function encode-time) (funcall fn string)))))))

(defun w3m-sub-list (list n)
  "Return a list of the first N elements of LIST.
If N is negative, return a list of the last N elements of LIST."
  (if (integerp n)
      (if (< n 0)
	  ;; N is negative, extract the last items
	  (if (>= (- n) (length list))
	      (copy-sequence list)
	    (nthcdr (+ (length list) n) (copy-sequence list)))
	;; N is positive, extract the first items
	(if (>= n (length list))
	    (copy-sequence list)
	  (nreverse (nthcdr (- (length list) n) (reverse list)))))
    (copy-sequence list)))

(defun w3m-load-list (file &optional coding-system)
  "Read an emacs-w3m data file FILE and return contents as a list.
It is used for loading `w3m-arrived-file', `w3m-cookie-file',
`w3m-favicon-cache-file' and `w3m-antenna-file' (which see).
CODING-SYSTEM is used to read FILE which defaults to the value of
`w3m-file-coding-system-for-read'."
  (when (and (file-readable-p file)
	     ;; XEmacs 21.4 might crash when inserting a directory.
	     (not (file-directory-p file)))
    (with-temp-buffer
      (when (condition-case nil
		(let ((coding-system-for-read
		       (or coding-system
			   w3m-file-coding-system-for-read))
		      (file-coding-system-for-read
		       (or coding-system
			   w3m-file-coding-system-for-read
			   (if (boundp 'file-coding-system-for-read)
			       (symbol-value 'file-coding-system-for-read)))))
		  (insert-file-contents file))
	      (error
	       (message "Error while loading %s" file)
	       nil))
	;; point is not always moved to the beginning of the buffer
	;; after `insert-file-contents' is done.
	(goto-char (point-min))
	(condition-case err
	    (read (current-buffer))
	  (error
	   (message "Error while reading %s; %s"
		    file (error-message-string err))
	   nil))))))

(defun w3m-save-list (file list &optional coding-system escape-ctl-chars)
  "Save a LIST form into the emacs-w3m data file FILE.
Contents will be encoded with CODING-SYSTEM which defaults to the
value of `w3m-file-coding-system'.  Optional ESCAPE-CTL-CHARS if it is
non-nil, control chars will be represented with ^ as `cat -v' does."
  (when (and list (file-writable-p file))
    (with-temp-buffer
      (let ((file-coding-system (or coding-system w3m-file-coding-system))
	    (coding-system-for-write (or coding-system w3m-file-coding-system))
	    (standard-output (current-buffer))
	    (print-fn (if escape-ctl-chars
			  'w3m-prin1
			'prin1))
	    element print-length print-level)
	(insert (format "\
;;; %s  -*- mode: emacs-lisp%s -*-
;; This file is generated automatically by emacs-w3m v%s.

"
			(file-name-nondirectory file)
			(if coding-system-for-write
			    (format "; coding: %s" coding-system-for-write)
			  "")
			emacs-w3m-version))
	(insert "(")
	(while list
	  (setq element (car list)
		list (cdr list))
	  (if (consp element)
	      (progn
		(insert "(")
		(funcall print-fn (car element))
		(insert "\n")
		(while (setq element (cdr element))
		  (insert "  ")
		  (funcall print-fn (car element))
		  (insert "\n"))
		(backward-delete-char 1)
		(insert ")\n "))
	    (funcall print-fn element)
	    (insert "\n")))
	(skip-chars-backward "\n ")
	(delete-region (point) (point-max))
	(insert ")\n")
	(let ((mode (and (file-exists-p file)
			 (file-modes file))))
	  (write-region (point-min) (point-max) file nil 'nomsg)
	  (when mode (set-file-modes file mode)))))))

(defun w3m-url-encode-string (str &optional coding)
  (apply (function concat)
	 (mapcar
	  (lambda (ch)
	    (cond
	     ((eq ch ?\n)		; newline
	      "%0D%0A")
	     ((string-match "[-a-zA-Z0-9_:/.]" (char-to-string ch)) ; xxx?
	      (char-to-string ch))	; printable
	     ((char-equal ch ?\x20)	; space
	      "+")
	     (t
	      (format "%%%02x" ch))))	; escape
	  ;; Coerce a string into a list of chars.
	  (append (encode-coding-string (or str "")
					(or coding
					    w3m-default-coding-system
					    w3m-coding-system
					    'iso-2022-7bit))
		  nil))))

(defun w3m-url-decode-string (str &optional coding)
  (let ((start 0)
	(buf))
    (while (string-match "+\\|%\\(0D%0A\\|\\([0-9a-fA-F][0-9a-fA-F]\\)\\)"
			 str start)
      (push (substring str start (match-beginning 0)) buf)
      (push (cond
	     ((match-beginning 2)
	      (vector (string-to-number (match-string 2 str) 16)))
	     ((match-beginning 1) "\n")
	     (t " "))
	    buf)
      (setq start (match-end 0)))
    (decode-coding-string
     (apply 'concat (nreverse (cons (substring str start) buf)))
     (or coding
	 w3m-default-coding-system
	 w3m-coding-system
	 'iso-2022-7bit))))

(defsubst w3m-url-transfer-encode-string (url &optional coding)
  "Encode non-ascii characters in URL into the sequence of escaped octets.
CODING which defaults to `w3m-current-coding-system' (which see) is a
coding system used when encoding non-ascii characters.

This function is designed for conversion for safe transmission of URL,
i.e., it handles only non-ASCII characters that can not be transmitted
safely through the network.  For the other general purpose, you should
use `w3m-url-encode-string' instead."
  (let ((start 0)
	(buf))
    (while (string-match "[^\x21-\x7e]+" url start)
      (setq buf
	    (cons (apply 'concat
			 (mapcar
			  (lambda (c) (format "%%%02x" c))
			  (append (encode-coding-string
				   (match-string 0 url)
				   (or coding
				       w3m-current-coding-system)))))
		  (cons (substring url start (match-beginning 0))
			buf))
	    start (match-end 0)))
    (apply 'concat
	   (nreverse (cons (substring url start) buf)))))


;;; HTML character entity handling:
(defun w3m-entity-db-setup ()
  "Initialize the hash table of `w3m-entity-alist'."
  (setq w3m-entity-db (make-vector w3m-entity-db-size 0))
  (dolist (elem w3m-entity-alist)
    (set (intern (car elem) w3m-entity-db)
	 (cdr elem))))

(eval-and-compile
  (unless (fboundp 'w3m-ucs-to-char)
    (defun w3m-ucs-to-char (codepoint)
      "A dummy function defined since nothing provided the regular function.
This function simply returns the arg if it is between 0x20 and 0x7e,
otherwise returns the tilde character."
      (if (or (< codepoint 32) (< 127 codepoint))
	  ?~ ;; unsupported character
	codepoint))))

(defun w3m-entity-value (name strict)
  "Get a char corresponding to NAME from the html char entities database.
The database is kept in `w3m-entity-db'.  If STRICT is non-nil, the
exact match with NAME is made.  Otherwise, it allows trailing extra
characters in NAME, but those characters appear in the return value.
For example:

\(w3m-entity-value \"ampersand\" t) => nil
\(w3m-entity-value \"ampersand\" nil) => \"&ersand\""
  (unless w3m-entity-db
    ;; Initialize the hash table.
    (w3m-entity-db-setup))
  ;; Return a value of the specified entity, or nil if it is unknown.
  (if (char-equal (string-to-char name) ?#)
      (progn
	(setq name (substring name 1))
	(let ((codepoint (if (char-equal (string-to-char name) ?x)
			     (string-to-number (substring name 1) 16)
			   (string-to-number name))))
	  (char-to-string (w3m-ucs-to-char codepoint))))
    (let ((val (intern-soft name w3m-entity-db))
	  (pre name)
	  (post ""))
      (if (not strict)
	  (while (and (null val)
		      (< 0 (length pre))
		      (null (setq val (intern-soft pre w3m-entity-db))))
	    (setq post (concat (substring pre -1) post)
		  pre (substring pre 0 -1))))
      (and val (concat (symbol-value val) post)))))

(defun w3m-fontify-bold ()
  "Fontify bold text in the buffer containing halfdump."
  (goto-char (point-min))
  (while (search-forward "<b>" nil t)
    (let ((start (match-beginning 0)))
      (delete-region start (match-end 0))
      (when (re-search-forward "</b[ \t\r\f\n]*>" nil t)
	(delete-region (match-beginning 0) (match-end 0))
	(w3m-add-text-properties start (match-beginning 0)
				 '(face w3m-bold-face))))))

(defun w3m-fontify-underline ()
  "Fontify underline text in the buffer containing halfdump."
  (goto-char (point-min))
  (while (search-forward "<u>" nil t)
    (let ((start (match-beginning 0)))
      (delete-region start (match-end 0))
      (when (re-search-forward "</u[ \t\r\f\n]*>" nil t)
	(delete-region (match-beginning 0) (match-end 0))
	(w3m-add-text-properties start (match-beginning 0)
				 '(face w3m-underline-face))))))

(defun w3m-fontify-strike-through ()
  "Fontify strike-through text in the buffer containing halfdump."
  (when (and w3m-fontify-strike-through
	     (w3m-static-if (featurep 'xemacs)
		 (device-on-window-system-p)
	       window-system))
    (goto-char (point-min))
    (while (re-search-forward "\\[\\(DEL\\|S\\):" nil t)
      (let ((start (match-beginning 0)))
	(delete-region start (match-end 0))
	(when (re-search-forward ":\\(DEL\\|S\\)]" nil t)
	  (delete-region (match-beginning 0) (match-end 0))
	  (w3m-add-text-properties start (match-beginning 0)
				   '(face w3m-strike-through-face)))))))

(defsubst w3m-decode-anchor-string (str)
  ;; FIXME: This is a quite ad-hoc function to process encoded url string.
  ;; More discussion about timing &-sequence decode is required.  The
  ;; following article (written in Japanese) is the origin of this issue:
  ;;
  ;; [emacs-w3m:00150] <URL:http://emacs-w3m.namazu.org/ml/msg00149.html>
  ;;
  ;; Takaaki MORIYAMA wrote in the article that the string "&amp;" which
  ;; is replaced from "&" and embedded in the w3m's halfdump should be
  ;; restored into "&" some time.
  (let ((start 0) (buf))
    (while (string-match "&amp;" str start)
      (setq buf (cons "&" (cons (substring str start (match-beginning 0)) buf))
	    start (match-end 0)))
    (apply (function concat)
	   (nreverse (cons (substring str start) buf)))))

(defun w3m-image-type (content-type)
  "Return an image type which corresponds to CONTENT-TYPE."
  (cdr (assoc content-type w3m-image-type-alist)))

(defun w3m-imitate-widget-button ()
  "Return a boolean value corresponding to the variable of the same name."
  (if (listp w3m-imitate-widget-button)
      (condition-case nil
	  (eval w3m-imitate-widget-button)
	(error nil))
    (and w3m-imitate-widget-button t)))

(defun w3m-fontify-anchors ()
  "Fontify anchor tags in the buffer which contains halfdump."
  (let ((help (w3m-make-help-echo w3m-href-anchor))
	(balloon (w3m-make-balloon-help w3m-href-anchor))
	prenames start end)
    (goto-char (point-min))
    (setq w3m-max-anchor-sequence 0)	;; reset max-hseq
    (while (re-search-forward "<_id[ \t\r\f\n]+" nil t)
      (setq start (match-beginning 0))
      (setq prenames (get-text-property start 'w3m-name-anchor))
      (w3m-parse-attributes (id)
	(delete-region start (point))
	(w3m-add-text-properties start (point-max)
				 (list 'w3m-name-anchor
				       (cons id prenames)))))
    (goto-char (point-min))
    (while (re-search-forward "<a[ \t\r\f\n]+" nil t)
      (setq start (match-beginning 0))
      (setq prenames (get-text-property start 'w3m-name-anchor))
      (w3m-parse-attributes (href name id charset
				  (rel :case-ignore) (hseq :integer))
	(unless name
	  (setq name id))
	(when rel
	  (setq rel (split-string rel))
	  (cond
	   ((member "next" rel) (setq w3m-next-url href))
	   ((or (member "prev" rel) (member "previous" rel))
	    (setq w3m-previous-url href))
	   ((member "start" rel) (setq w3m-start-url href))
	   ((member "contents" rel) (setq w3m-contents-url href))))
	(delete-region start (point))
	(cond
	 (href
	  (when (re-search-forward "[ \t\r\f\n]*\\(</a>\\)" nil t)
	    (setq end (match-beginning 0))
	    (delete-region (match-beginning 1) (match-end 1))
	    (setq href (w3m-expand-url (w3m-decode-anchor-string href)))
	    (setq href (if (and (string-match w3m-url-components-regexp href)
				(match-beginning 8))
			   (concat (w3m-url-transfer-encode-string
				    (substring href 0 (match-beginning 8))
				    (w3m-charset-to-coding-system charset))
				   "#" (match-string 9 href))
			 (w3m-url-transfer-encode-string
			  href
			  (w3m-charset-to-coding-system charset)))
		  hseq (or (and (null hseq) 0) (abs hseq))
		  w3m-max-anchor-sequence (max hseq w3m-max-anchor-sequence))
	    (w3m-add-text-properties start end
				     (list 'face (if (w3m-arrived-p href)
						     'w3m-arrived-anchor-face
						   'w3m-anchor-face)
					   'w3m-href-anchor href
					   'mouse-face 'highlight
					   'w3m-anchor-sequence hseq
					   'help-echo help
					   'balloon-help balloon))
	    (when (w3m-imitate-widget-button)
	      (require 'wid-edit)
	      (let ((widget-button-face (if (w3m-arrived-p href)
					    'w3m-arrived-anchor-face
					  'w3m-anchor-face))
		    (widget-mouse-face 'highlight)
		    w)
		(setq w (widget-convert-button 'default start end
					       :button-keymap nil
					       :help-echo href))
		(w3m-static-unless (featurep 'xemacs)
		  (overlay-put (widget-get w :button-overlay) 'evaporate t))))
	    (when name
	      (w3m-add-text-properties start (point-max)
				       (list 'w3m-name-anchor
					     (cons name prenames))))))
	 (name
	  (w3m-add-text-properties start (point-max)
				   (list 'w3m-name-anchor
					 (cons name prenames)))))))
    (when w3m-icon-data
      (setq w3m-icon-data (cons (w3m-expand-url (car w3m-icon-data))
				(or (w3m-image-type (cdr w3m-icon-data))
				    'ico))))
    (when w3m-next-url
      (setq w3m-next-url (w3m-expand-url w3m-next-url)))
    (when w3m-previous-url
      (setq w3m-previous-url (w3m-expand-url w3m-previous-url)))
    (when w3m-start-url
      (setq w3m-start-url (w3m-expand-url w3m-start-url)))
    (when w3m-contents-url
      (setq w3m-contents-url (w3m-expand-url w3m-contents-url)))))

(eval-and-compile
  (unless (featurep 'xemacs)
    (defun w3m-setup-menu ()
      "Define menubar buttons for Emacsen."
      (let ((items (mapcar 'car (cdr (lookup-key global-map [menu-bar])))))
	(when items
	  ;; Place the W3M menu in the forefront of the menubar.
	  (set (make-local-variable 'menu-bar-final-items)
	       (delq 'w3m items))))
      (unless (keymapp (lookup-key w3m-mode-map [menu-bar w3m]))
	(let ((map (make-sparse-keymap (car w3m-menubar))))
	  (define-key w3m-mode-map [menu-bar] (make-sparse-keymap))
	  (when w3m-use-tab-menubar (w3m-setup-tab-menu))
	  (define-key w3m-mode-map [menu-bar w3m] (cons (car w3m-menubar) map))
	  (dolist (def (reverse (cdr w3m-menubar)))
	    (define-key map (vector (aref def 1)) (cons (aref def 0)
							(aref def 1)))
	    (put (aref def 1) 'menu-enable (aref def 2)))
	  ;;(define-key map [separator-eval] '("--"))
	  )))))

(defun w3m-fontify-images ()
  "Fontify img_alt strings of images in the buffer containing halfdump."
  (goto-char (point-min))
  (let ((help (w3m-make-help-echo w3m-image))
	(balloon (w3m-make-balloon-help w3m-image))
	upper start end)
    (while (re-search-forward "<\\(img_alt\\)[^>]+>" nil t)
      (setq upper (string= (match-string 1) "IMG_ALT")
	    start (match-beginning 0)
	    end (match-end 0))
      (goto-char (match-end 1))
      (w3m-parse-attributes (src
			     (width :integer)
			     (height :integer)
			     usemap)
	(delete-region start end)
	(setq src (w3m-expand-url (w3m-decode-anchor-string src)))
	(when (search-forward "</img_alt>" nil t)
	  (delete-region (setq end (match-beginning 0)) (match-end 0))
	  (w3m-add-text-properties start end
				   (list 'w3m-image src
					 'w3m-image-size
					 (when (or width height)
					   (cons width height))
					 'w3m-image-usemap usemap
					 'w3m-image-status 'off
					 'w3m-image-redundant upper))
	  (unless (or (w3m-anchor start)
		      (w3m-action start))
	    ;; No need to use `w3m-add-text-properties' here.
	    (add-text-properties start end (list 'face 'w3m-image-face
						 'mouse-face 'highlight
						 'help-echo help
						 'balloon-help balloon))))))))

(defsubst w3m-toggle-inline-images-internal (status no-cache url)
  "Toggle displaying of inline images on current buffer.
STATUS is current image status.
If NO-CACHE is non-nil, cache is not used.
If URL is specified, only the image with URL is toggled."
  (interactive "P")
  (let ((cur-point (point))
	(buffer-read-only)
	(end (point-min))
	start iurl image size)
    (save-excursion
      (if (equal status 'off)
	  (while (setq start
		       (if (w3m-image end)
			   end
			 (next-single-property-change end 'w3m-image)))
	    (setq end (or (next-single-property-change start 'w3m-image)
			  (point-max))
		  iurl (w3m-image start)
		  size (get-text-property start 'w3m-image-size))
	    (when (and (or (not url)
			   ;; URL is specified and is same as the image URL.
			   (string= url iurl))
		       (not (eq (get-text-property start 'w3m-image-status)
				'on)))
	      (w3m-add-text-properties start end '(w3m-image-status on))
	      (if (get-text-property start 'w3m-image-redundant)
		  (progn
		    ;; Insert a dummy string instead of a redundant image.
		    (setq image (make-string
				 (string-width (buffer-substring start end))
				 ? ))
		    (w3m-add-text-properties start end '(invisible t))
		    (goto-char end)
		    (w3m-add-text-properties
		     end (progn (insert image) (point))
		     '(w3m-image-dummy t w3m-image "dummy"))
		    (setq end (point)))
		(goto-char cur-point)
		(when (w3m-url-valid iurl)
		  (w3m-process-with-null-handler
		    (lexical-let ((start (set-marker (make-marker) start))
				  (end (set-marker (make-marker) end))
				  (iurl iurl)
				  (url w3m-current-url))
		      (w3m-process-do
			  (image (let ((w3m-current-buffer (current-buffer)))
				   (w3m-create-image
				    iurl no-cache
				    w3m-current-url
				    size handler)))
			(when (buffer-live-p (marker-buffer start))
			  (with-current-buffer (marker-buffer start)
			    (if image
				(when (equal url w3m-current-url)
				  (let (buffer-read-only)
				    (w3m-insert-image start end image iurl))
				  ;; Redisplay
				  (when w3m-force-redisplay
				    (sit-for 0)))
			      (let (buffer-read-only)
				(w3m-add-text-properties
				 start end '(w3m-image-status off))))
			    (set-buffer-modified-p nil))
			  (set-marker start nil)
			  (set-marker end nil)))))))))
	;; Remove.
	(while (setq start (if (w3m-image end)
			       end
			     (next-single-property-change end 'w3m-image)))
	  (setq end (or (next-single-property-change start 'w3m-image)
			(point-max))
		iurl (w3m-image start))
	  ;; IMAGE-ALT-STRING DUMMY-STRING
	  ;; <--------w3m-image---------->
	  ;; <---redundant--><---dummy--->
	  ;; <---invisible-->
	  (when (and (or (not url)
			 ;; URL is specified and is not same as the image URL.
			 (string= url iurl))
		     (not (eq (get-text-property start 'w3m-image-status)
			      'off)))
	    (cond
	     ((get-text-property start 'w3m-image-redundant)
	      ;; Remove invisible property.
	      (put-text-property start end 'invisible nil))
	     ((get-text-property start 'w3m-image-dummy)
	      ;; Remove dummy string.
	      (delete-region start end)
	      (setq end start))
	     ((get-text-property start 'w3m-bitmap-image)
	      (goto-char end)
	      (setq end (w3m-remove-image start end)))
	     (t (w3m-remove-image start end)))
	    (w3m-add-text-properties start end '(w3m-image-status off))))
	(set-buffer-modified-p nil)))))

(defun w3m-toggle-inline-image (&optional force no-cache)
  "Toggle the visibility of an image under point.
If FORCE is non-nil, displaying an image is forced.  If NO-CACHE is
non-nil, cached data will not be used."
  (interactive "P")
  (unless (w3m-display-graphic-p)
    (error "Can't display images in this environment"))
  (let ((url (w3m-image))
	(status (get-text-property (point) 'w3m-image-status))
	(scale (get-text-property (point) 'w3m-image-scale)))
    (if (and scale (equal status 'off))
	(w3m-zoom-in-image 0)
      (if (w3m-url-valid url)
	  (progn
	    (if force (setq status 'off))
	    (w3m-toggle-inline-images-internal status no-cache url))
	(w3m-message "No image at point")))))

(defun w3m-toggle-inline-images (&optional force no-cache)
  "Toggle the visibility of all images in the buffer.
If FORCE is non-nil, displaying images is forced.  If NO-CACHE is
non-nil, cached data will not be used."
  (interactive "P")
  (let ((status w3m-display-inline-images))
    (unless (w3m-display-graphic-p)
      (error "Can't display images in this environment"))
    (if force (setq w3m-display-inline-images nil
		    status nil))
    (unwind-protect
	(w3m-toggle-inline-images-internal (if w3m-display-inline-images
					       'on 'off)
					   no-cache nil)
      (unless (setq w3m-display-inline-images (not status))
	(w3m-process-stop (current-buffer)))
      (force-mode-line-update))))

(defsubst w3m-resize-inline-image-internal (url rate)
  "Resize an inline image on the cursor position.
URL is a url of an image.  RATE is a number of percent used when
resizing an image."
  (interactive "P")
  (let ((buffer-read-only)
	start end iurl image size iscale scale)
    (if (or (featurep 'xemacs)
	    (>= emacs-major-version 21))
	(progn
	  (setq start (point)
		end (or (next-single-property-change start 'w3m-image)
			(point-max))
		iurl (w3m-image start)))
      ;; The case of using BITMAP-MULE:
      ;; Look for the start and the end positions of the first line of
      ;; a bitmap image.
      (setq end (point-min)
	    iurl "")
      (while (and (not (string-equal url iurl))
		  (setq start
			(if (w3m-image end)
			    end
			  (next-single-property-change end 'w3m-image))))
	(setq end (or (next-single-property-change start 'w3m-image)
		      (point-max))
	      iurl (w3m-image start)))
      (goto-char start)
      ;; Remove an existing bitmap image.
      (let ((inhibit-read-only t))
	(setq end (or (w3m-remove-image start end) end))))
    (setq size (get-text-property start 'w3m-image-size)
	  iscale (or (get-text-property start 'w3m-image-scale) '100))
    (w3m-add-text-properties start end '(w3m-image-status on))
    (setq scale (truncate (* iscale rate 0.01)))
    (w3m-add-text-properties start end (list 'w3m-image-scale scale))
    (if (get-text-property start 'w3m-image-redundant)
	(progn
	  ;; Insert a dummy string instead of a redundant image.
	  (setq image (make-string
		       (string-width (buffer-substring start end))
		       ? ))
	  (w3m-add-text-properties start end '(invisible t))
	  (w3m-add-text-properties (point)
				   (progn (insert image) (point))
				   '(w3m-image-dummy t
						     w3m-image "dummy")))
      (when iurl
	(w3m-process-with-null-handler
	  (lexical-let ((start (set-marker (make-marker) start))
			(end (set-marker (make-marker) end))
			(iurl iurl)
			(rate scale)
			(url w3m-current-url))
	    (w3m-process-do
		(image (let ((w3m-current-buffer (current-buffer)))
			 (w3m-create-resized-image
			  iurl
			  rate
			  w3m-current-url
			  size handler)))
	      (when (buffer-live-p (marker-buffer start))
		(with-current-buffer (marker-buffer start)
		  (if image
		      (when (equal url w3m-current-url)
			(let (buffer-read-only)
			  (w3m-static-when (featurep 'xemacs)
			    (w3m-remove-image start end))
			  (w3m-insert-image start end image iurl))
			;; Redisplay
			(when w3m-force-redisplay
			  (sit-for 0)))
		    (let (buffer-read-only)
		      (w3m-add-text-properties
		       start end '(w3m-image-status off))))
		  (set-buffer-modified-p nil))
		(set-marker start nil)
		(set-marker end nil)))))))))

(defun w3m-zoom-in-image (&optional rate)
  "Zoom in an image on the point."
  (interactive "P")
  (unless (w3m-display-graphic-p)
    (error "Can't display images in this environment"))
  (let ((url (w3m-image)))
    (unless rate
      (setq rate w3m-resize-image-scale))
    (if url
	(w3m-resize-inline-image-internal url (+ 100 rate))
      (w3m-message "No image at point"))))

(defun w3m-zoom-out-image (&optional rate)
  "Zoom out an image on the point."
  (interactive "P")
  (unless (w3m-display-graphic-p)
    (error "Can't display images in this environment"))
  (let ((url (w3m-image)))
    (unless rate
      (setq rate w3m-resize-image-scale))
    (if url
	(w3m-resize-inline-image-internal url (- 100 rate))
      (w3m-message "No image at point"))))

(defun w3m-decode-entities (&optional reserve-prop)
  "Decode entities in the current buffer.
If optional RESERVE-PROP is non-nil, text property is reserved."
  (save-excursion
    (goto-char (point-min))
    (let (start prop value)
      (while (re-search-forward w3m-entity-regexp nil t)
	(setq start (match-beginning 0))
	(if reserve-prop
	    (setq prop (text-properties-at (match-beginning 0))))
	;; Note that `w3m-entity-value' breaks `match-data' at the 1st
	;; time in XEmacs because of the autoloading unicode.elc for
	;; the `ucs-to-char' function.
	(when (setq value (w3m-entity-value (match-string 1)
					    (match-beginning 2)))
	  (replace-match value nil t))
	(if (and reserve-prop prop)
	    (w3m-add-text-properties start (point) prop))))))

(defun w3m-decode-entities-string (str)
  "Decode entities in the string STR."
  (save-match-data
    (with-temp-buffer
      (insert str)
      (w3m-decode-entities)
      (buffer-string))))

(defun w3m-encode-specials-string (str)
  "Encode special characters in the string STR."
  (let ((pos 0)
	(buf))
    (while (string-match "[<>&]" str pos)
      (setq buf
	    (cons ";"
		  (cons (car (rassoc (match-string 0 str) w3m-entity-alist))
			(cons "&"
			      (cons (substring str pos (match-beginning 0))
				    buf))))
	    pos (match-end 0)))
    (if buf
	(apply 'concat (nreverse (cons (substring str pos) buf)))
      str)))

(defun w3m-fontify ()
  "Fontify the current buffer."
  (let ((case-fold-search t)
	(buffer-read-only))
    (run-hooks 'w3m-fontify-before-hook)
    (w3m-message "Fontifying...")
    ;; Delete <?xml ... ?> tag
    (goto-char (point-min))
    (if (search-forward "<?xml" nil t)
	(let ((start (match-beginning 0)))
	  (search-forward "?>" nil t)
	  (delete-region start (match-end 0))))
    ;; Delete extra title tag.
    (goto-char (point-min))
    (let (start)
      (and (search-forward "<title>" nil t)
	   (setq start (match-beginning 0))
	   (search-forward "</title>" nil t)
	   (delete-region start (match-end 0))))
    (w3m-fontify-bold)
    (w3m-fontify-strike-through)
    (w3m-fontify-underline)
    (when w3m-use-symbol
      (w3m-replace-symbol))
    (w3m-fontify-anchors)
    (when w3m-use-form
      (w3m-fontify-forms))
    (w3m-fontify-images)
    ;; Remove other markups.
    (goto-char (point-min))
    (while (re-search-forward "</?[A-Za-z_][^>]*>" nil t)
      (let ((fid (get-text-property (match-beginning 0) 'w3m-form-field-id)))
	(if (and fid (string-match "/type=textarea/" fid))
	    (goto-char (match-end 0))
	  (delete-region (match-beginning 0) (match-end 0)))))
    ;; Decode escaped characters (entities).
    (w3m-decode-entities 'reserve-prop)
    (when w3m-use-form
      (w3m-fontify-textareas))
    (goto-char (point-min))
    (when w3m-delete-duplicated-empty-lines
      (while (re-search-forward "^[ \t]*\n\\([ \t]*\n\\)+" nil t)
	(delete-region (match-beginning 0) (1- (match-end 0)))))
    (w3m-message "Fontifying...done")
    (w3m-header-line-insert)
    (run-hooks 'w3m-fontify-after-hook)))

;;

(defun w3m-refontify-anchor (&optional buff)
  "Refontify anchors as they have already arrived.
It replaces the faces on the arrived anchors from `w3m-anchor-face' to
`w3m-arrived-anchor-face'."
  (save-excursion
    (and buff (set-buffer buff))
    (when (and (eq major-mode 'w3m-mode)
	       (eq (get-text-property (point) 'face) 'w3m-anchor-face))
      (let* ((start)
	     (end (next-single-property-change (point) 'face))
	     (buffer-read-only))
	(when (and end
		   (setq start (previous-single-property-change end 'face)))
	  (w3m-add-text-properties start end '(face w3m-arrived-anchor-face)))
	(set-buffer-modified-p nil)))))

(defun w3m-url-completion (url predicate flag)
  "Completion function for URL."
  (if (string-match "\\`\\(file:\\|[/~]\\|\\.\\.?/\\|[a-zA-Z]:\\)" url)
      (if (eq flag 'lambda)
	  (file-exists-p (w3m-url-to-file-name url))
	(let* ((partial
		(expand-file-name
		 (cond
		  ((string-match "\\`file:[^/]" url)
		   (substring url 5))
		  ((string-match "/\\(~\\)" url)
		   (substring url (match-beginning 1)))
		  (t (w3m-url-to-file-name url)))))
	       (collection
		(let ((dir (file-name-directory partial)))
		  (mapcar
		   (lambda (f)
		     (list (w3m-expand-file-name-as-url f dir)))
		   (file-name-all-completions (file-name-nondirectory partial)
					      dir)))))
	  (setq partial
		(if (string-match "/\\.\\'" url)
		    (concat (file-name-as-directory
			     (w3m-expand-file-name-as-url partial))
			    ".")
		  (w3m-expand-file-name-as-url partial)))
	  (cond
	   ((not flag)
	    (try-completion partial collection predicate))
	   ((eq flag t)
	    (all-completions partial collection predicate)))))
    (cond
     ((not flag)
      (try-completion url w3m-arrived-db))
     ((eq flag t)
      (all-completions url w3m-arrived-db))
     ((eq flag 'lambda)
      (if (w3m-arrived-p url) t nil)))))

(eval-and-compile
  (cond
   ((locate-library "ffap")
    (autoload 'ffap-url-at-point "ffap")
    (if (featurep 'xemacs)
	(if (featurep 'mule)
	    (defun w3m-url-at-point ()
	      "\
Like `ffap-url-at-point', except that text props will be stripped and
iso646 characters are unified into ascii characters."
	      (let ((left (buffer-substring-no-properties (point-at-bol)
							  (point)))
		    (right (buffer-substring-no-properties (point)
							   (point-at-eol)))
		    (regexp (format "[%c-%c]"
				    (make-char 'latin-jisx0201 33)
				    (make-char 'latin-jisx0201 126)))
		    (diff (- (char-to-int (make-char 'latin-jisx0201 33)) 33))
		    index)
		(while (setq index (string-match regexp left))
		  (aset left index (- (aref left index) diff)))
		(while (setq index (string-match regexp right))
		  (aset right index (- (aref right index) diff)))
		(with-temp-buffer
		  (insert right)
		  (goto-char (point-min))
		  (insert left)
		  (ffap-url-at-point))))
	  (defun w3m-url-at-point ()
	    "\
Like `ffap-url-at-point', except that text props will be stripped."
	    (unless (fboundp 'ffap-url-at-point)
	      ;; It is necessary to bind `ffap-xemacs'.
	      (load "ffap" nil t))
	    (let (ffap-xemacs)
	      (ffap-url-at-point))))
      (defalias 'w3m-url-at-point 'ffap-url-at-point))
    (eval-after-load "ffap"
      '(progn
	 ;; Under Emacs 19, 20 or XEmacs, `ffap-url-regexp' won't match
	 ;; to https urls by default.
	 (if (and ffap-url-regexp
		  (not (string-match ffap-url-regexp "https://foo"))
		  (string-match "\\((\\|\\\\|\\)\\(http\\)\\(\\\\|\\|\\\\)\\)"
				ffap-url-regexp))
	     (setq ffap-url-regexp (replace-match "\\1\\2s?\\3"
						  nil nil ffap-url-regexp)))
	 ;; Add nntp:.
	 (if (and ffap-url-regexp
		  (not (string-match ffap-url-regexp "nntp://bar"))
		  (string-match "\\(\\\\(news\\\\(post\\\\)\\?:\\)\\(\\\\|\\)"
				ffap-url-regexp))
	     (setq ffap-url-regexp (replace-match "\\1\\\\|nntp:\\2"
						  nil nil ffap-url-regexp))))))
   ((locate-library "thingatpt")
    (autoload 'thing-at-point "thingatpt")
    (defun w3m-url-at-point ()
      "Return url from around point if it exists, or nil."
      (let ((url (thing-at-point 'url)))
	(when url
	  (set-text-properties 0 (length url) nil url)
	  url))))
   (t
    (defalias 'w3m-url-at-point 'ignore))))

(defun w3m-active-region-or-url-at-point ()
  "Return an active region or a url around the cursor.
In Transient Mark mode, deactivate the mark."
  (if (w3m-region-active-p)
      (prog1
	  (w3m-replace-in-string (buffer-substring-no-properties
				  (region-beginning) (region-end))
				 "[\t\r\f\n $B!!(B]+" "")
	(w3m-deactivate-region))
    (w3m-url-at-point)))

(defsubst w3m-canonicalize-url (url)
  "Add a scheme part to an URL if it has no scheme part."
  (if (and (string-match w3m-url-components-regexp url)
	   (match-beginning 1))
      url
    (concat (if (and (file-name-absolute-p url)
		     (file-exists-p url))
		"file://"
	      "http://")
	    url)))

(defun w3m-input-url (&optional prompt initial default quick-start)
  "Read a url from the minibuffer, prompting with string PROMPT."
  (let (url)
    (w3m-arrived-setup)
    (unless default
      (setq default w3m-home-page))
    (unless initial
      (setq initial (w3m-active-region-or-url-at-point)))
    (if (and quick-start
	     default
	     (not initial))
	default
      (setq url (let ((minibuffer-setup-hook
		       (append minibuffer-setup-hook '(beginning-of-line))))
		  (completing-read
		   (or prompt
		       (if default
			   (format "URL (default %s): "
				   (if (stringp default)
				       (if (eq default w3m-home-page)
					   "HOME" default)
				     (prin1-to-string default)))
			 "URL: "))
		   'w3m-url-completion nil nil initial
		   'w3m-input-url-history)))
      (when (string= "" url)
	(setq url default))
      (if (stringp url)
	  (progn
	    ;; remove duplication
	    (setq w3m-input-url-history
		  (cons url (delete url w3m-input-url-history)))
	    (w3m-canonicalize-url url))
	;; It may be `popup'.
	url))))


;;; Cache:
(defun w3m-cache-setup ()
  "Initialize the variables for managing the cache."
  (unless (and (bufferp w3m-cache-buffer)
	       (buffer-live-p w3m-cache-buffer))
    (save-excursion
      (set-buffer (w3m-get-buffer-create " *w3m cache*"))
      (buffer-disable-undo)
      (set-buffer-multibyte nil)
      (setq buffer-read-only t
	    w3m-cache-buffer (current-buffer)
	    w3m-cache-hashtb (make-vector 1021 0)))))

(defun w3m-cache-shutdown ()
  "Clear all the variables managing the cache, and the cache itself."
  (when (buffer-live-p w3m-cache-buffer)
    (kill-buffer w3m-cache-buffer))
  (setq w3m-cache-hashtb nil
	w3m-cache-articles nil))

(defsubst w3m-cache-header-delete-variable-part (header)
  (let (buf)
    (dolist (line (split-string header "\n+"))
      (unless (string-match "\\`\\(Date\\|Server\\|W3m-[^:]+\\):" line)
	(push line buf)))
    (mapconcat (function identity) (nreverse buf) "\n")))

(defun w3m-cache-header (url header &optional overwrite)
  "Store HEADER into the cache so that it corresponds to URL.
If OVERWRITE is non-nil, it forces the storing even if there has
already been the data corresponding to URL in the cache."
  (w3m-cache-setup)
  (let ((ident (intern url w3m-cache-hashtb)))
    (if (boundp ident)
	(if (and
	     (not overwrite)
	     (string=
	      (w3m-cache-header-delete-variable-part header)
	      (w3m-cache-header-delete-variable-part (symbol-value ident))))
	    (symbol-value ident)
	  (w3m-cache-remove url)
	  (set ident header))
      (set ident header))))

(defun w3m-cache-request-header (url)
  "Return the header string of URL when it is stored in the cache."
  (w3m-cache-setup)
  (let ((ident (intern url w3m-cache-hashtb)))
    (and (boundp ident)
	 (symbol-value ident))))

(defun w3m-cache-remove-oldest ()
  (save-excursion
    (set-buffer w3m-cache-buffer)
    (goto-char (point-min))
    (unless (zerop (buffer-size))
      (let ((ident (get-text-property (point) 'w3m-cache))
	    buffer-read-only)
	;; Remove the ident from the list of articles.
	(when ident
	  (setq w3m-cache-articles (delq ident w3m-cache-articles)))
	;; Delete the article itself.
	(delete-region (point)
		       (next-single-property-change
			(1+ (point)) 'w3m-cache nil (point-max)))))))

(defun w3m-cache-remove (url)
  "Remove the data coresponding to URL from the cache."
  (w3m-cache-setup)
  (let ((ident (intern url w3m-cache-hashtb))
	beg end)
    (when (memq ident w3m-cache-articles)
      ;; It was in the cache.
      (save-excursion
	(set-buffer w3m-cache-buffer)
	(let (buffer-read-only)
	  (when (setq beg (text-property-any
			   (point-min) (point-max) 'w3m-cache ident))
	    ;; Find the end (i. e., the beginning of the next article).
	    (setq end (next-single-property-change
		       (1+ beg) 'w3m-cache (current-buffer) (point-max)))
	    (delete-region beg end)))
	(setq w3m-cache-articles (delq ident w3m-cache-articles))))))

(defun w3m-cache-contents (url buffer)
  "Store the contents of URL into the cache.
The contents are assumed to be in BUFFER.  Return a symbol which
identifies the data in the cache."
  (w3m-cache-setup)
  (let ((ident (intern url w3m-cache-hashtb)))
    (w3m-cache-remove url)
    ;; Remove the oldest article, if necessary.
    (and (numberp w3m-keep-cache-size)
	 (>= (length w3m-cache-articles) w3m-keep-cache-size)
	 (w3m-cache-remove-oldest))
    ;; Insert the new article.
    (save-excursion
      (set-buffer w3m-cache-buffer)
      (let (buffer-read-only)
	(goto-char (point-max))
	(let ((b (point)))
	  (insert-buffer-substring buffer)
	  ;; Tag the beginning of the article with the ident.
	  (when (> (point-max) b)
	    (w3m-add-text-properties b (1+ b) (list 'w3m-cache ident))
	    (setq w3m-cache-articles (cons ident w3m-cache-articles))
	    ident))))))

(defun w3m-cache-request-contents (url &optional buffer)
  "Insert contents of URL into BUFFER.
Return t if the contents are found in the cache, otherwise nil.  When
BUFFER is nil, all contents will be inserted in the current buffer."
  (w3m-cache-setup)
  (let ((ident (intern url w3m-cache-hashtb)))
    (when (memq ident w3m-cache-articles)
      ;; It was in the cache.
      (let (beg end)
	(save-excursion
	  (set-buffer w3m-cache-buffer)
	  (if (setq beg (text-property-any
			 (point-min) (point-max) 'w3m-cache ident))
	      ;; Find the end (i.e., the beginning of the next article).
	      (setq end (next-single-property-change
			 (1+ beg) 'w3m-cache (current-buffer) (point-max)))
	    ;; It wasn't in the cache after all.
	    (setq w3m-cache-articles (delq ident w3m-cache-articles))))
	(and beg
	     end
	     (save-excursion
	       (when buffer
		 (set-buffer buffer))
	       (let (buffer-read-only)
		 (insert-buffer-substring w3m-cache-buffer beg end))
	       t))))))

;; FIXME: we need to check whether contents were updated in remote servers.
(defun w3m-cache-available-p (url)
  "Return non-nil if a content of URL has already been cached."
  (w3m-cache-setup)
  (when (stringp url)
    (let ((ident (intern url w3m-cache-hashtb)))
      (and (memq ident w3m-cache-articles)
	   (or w3m-prefer-cache
	       (save-match-data
		 (let ((case-fold-search t)
		       (head (and (boundp ident) (symbol-value ident))))
		   (and (string-match "^\\(Last-Modified\\|ETag\\):[ \t]" head)
			(not (or (string-match "^Pragma:[ \t]+no-cache\n" head)
				 (string-match
				  "^Cache-control:[ \t]+\\(no-cache\\|max-age=0\\)\n"
				  head)))))))
	   ident))))

(defun w3m-read-file-name (&optional prompt dir default existing)
  (when default
    (setq default (file-name-nondirectory (w3m-url-strip-query default))))
  (unless prompt
    (setq prompt (if default
		     (format "Save to (%s): " default)
		   "Save to: ")))
  (setq dir (file-name-as-directory (or dir w3m-default-save-directory)))
  (let ((default-directory dir)
	(file (read-file-name prompt dir nil existing default)))
    (if (not (file-directory-p file))
	(setq w3m-default-save-directory
	      (or (file-name-directory file) w3m-default-save-directory))
      (setq w3m-default-save-directory file)
      (if default
	  (setq file (expand-file-name default file))))
    (expand-file-name file)))

;;; Handling character sets:
(defun w3m-charset-to-coding-system (charset)
  "Return a coding system which is most suitable to CHARSET.
CHARSET is a symbol whose name is MIME charset.
This function is imported from mcharset.el."
  (if (stringp charset)
      (setq charset (intern (downcase charset))))
  (let ((cs (assq charset w3m-charset-coding-system-alist)))
    (w3m-find-coding-system (if cs (cdr cs) charset))))

;; FIXME: we need to investigate the kind of Content-Charsets being
;; actually possible.
(defun w3m-read-content-charset (prompt &optional default)
  "Read a content charset from the minibuffer, prompting with string PROMPT.
The second argument DEFAULT is the default value, which is used as the
value to return if the user enters the empty string."
  (let ((charset (completing-read
		  prompt
		  (nconc
		   (mapcar (lambda (c) (cons (symbol-name c) c))
			   (coding-system-list))
		   (mapcar (lambda (c) (cons (symbol-name (car c)) c))
			   w3m-charset-coding-system-alist))
		  nil t)))
    (if (string= "" charset)
	default
      charset)))


;;; Handling encoding of contents:
(defun w3m-decode-encoded-contents (encoding)
  "Decode encoded contents in the current buffer.
It supports the encoding types of gzip, bzip2, deflate, etc."
  (let ((x (and (stringp encoding)
		(assoc (downcase encoding) w3m-encoding-alist))))
    (or (not (and x (setq x (cdr (assq (cdr x) w3m-decoder-alist)))))
	(let ((coding-system-for-write 'binary)
	      (coding-system-for-read 'binary)
	      (default-process-coding-system (cons 'binary 'binary)))
	  (w3m-process-with-environment w3m-command-environment
	    (w3m-static-if (featurep 'xemacs)
		(goto-char (point-max)))
	    (zerop (apply 'call-process-region
			  (point-min) (point-max)
			  (w3m-which-command (car x))
			  t '(t nil) nil (cadr x))))))))

(defmacro w3m-correct-charset (charset)
  `(or (and ,charset (stringp ,charset)
	    (cdr (assoc (downcase ,charset) w3m-correct-charset-alist)))
       ,charset))

(defun w3m-detect-meta-charset ()
  (let ((case-fold-search t))
    (goto-char (point-min))
    (catch 'found
      (while (re-search-forward "<meta[ \t\r\f\n]+" nil t)
	(w3m-parse-attributes ((http-equiv :case-ignore)
			       (content :case-ignore))
	  (when (and (string= http-equiv "content-type")
		     content
		     (string-match ";[ \t\n]*charset=\\([^\"]+\\)" content))
	    (throw 'found (match-string 1 content))))))))

(defun w3m-decode-buffer (url &optional content-charset content-type)
  (let (cs)
    (unless content-charset
      (setq content-charset
	    (or (w3m-content-charset url)
		(when (string= "text/html"
			       (or content-type (w3m-content-type url)))
		  (w3m-detect-meta-charset)))))
    (cond
     ((and (eq w3m-type 'w3mmee)
	   (or (and (stringp content-charset)
		    (string= "x-moe-internal" (downcase content-charset)))
	       (eq content-charset 'x-moe-internal)))
      (setq cs (w3m-x-moe-decode-buffer))
      (setq content-charset (symbol-name cs)))
     (content-charset
      (setq content-charset (w3m-correct-charset content-charset))
      (setq cs (w3m-charset-to-coding-system content-charset))))
    (setq w3m-current-content-charset content-charset)
    (decode-coding-region
     (point-min) (point-max)
     (setq w3m-current-coding-system
	   (or cs
	       (w3m-detect-coding-region
		(point-min) (point-max)
		(if (w3m-url-local-p url)
		    nil
		  w3m-coding-system-priority-list)))))
    (set-buffer-multibyte t)))

(defun w3m-x-moe-decode-buffer ()
  (let ((args '("-i" "-cs" "x-moe-internal"))
	(coding-system-for-read 'binary)
	(coding-system-for-write 'binary)
	(default-process-coding-system (cons 'binary 'binary))
	charset)
    (if (w3m-find-coding-system 'utf-8)
	(setq args (append args '("-o" "-cs" "utf-8"))
	      charset 'utf-8)
      (setq args
	    (append args (list "-o" "-cs" (symbol-name w3m-coding-system))))
      (setq charset w3m-coding-system))
    (w3m-process-with-environment w3m-command-environment
      (w3m-static-if (featurep 'xemacs)
	  (goto-char (point-max)))
      (apply 'call-process-region (point-min) (point-max)
	     w3m-mbconv-command t t nil args))
    charset))

(defun w3m-safe-decode-buffer (url &optional content-charset content-type)
  (and (not w3m-current-coding-system)
       (stringp content-type)
       (string-match "\\`text/" content-type)
       (w3m-decode-buffer url content-charset content-type)))

;;; Retrieving local data:
(defun w3m-local-file-type (url)
  "Return the content type and the content encoding of URL."
  (setq url (or (w3m-url-to-file-name url)
		(file-name-nondirectory url)))
  (if (and (file-name-absolute-p url)
	   (file-directory-p url))
      (cons "text/html" nil)
    (let ((encoding
	   (catch 'encoding-detected
	     (dolist (elem w3m-encoding-type-alist)
	       (when (string-match (car elem) url)
		 (setq url (substring url 0 (match-beginning 0)))
		 (throw 'encoding-detected (cdr elem)))))))
      (cons (catch 'type-detected
	      (dolist (elem w3m-content-type-alist)
		(when (and (cadr elem) (string-match (cadr elem) url))
		  (throw 'type-detected (car elem))))
	      "unknown")
	    encoding))))

(defmacro w3m-local-content-type (url)
  `(car (w3m-local-file-type ,url)))

(defun w3m-local-attributes (url &rest args)
  "Return a list of attributes corresponding to URL.
Return nil if it failed in retrieving of the header.
Otherwise, return a list which includes the following elements:

 0. Type of contents.
 1. Charset of contents.
 2. Size in bytes.
 3. Encoding of contents.
 4. Last modification time.
 5. Real URL.
"
  (let* ((file (w3m-url-to-file-name url))
	 (attr (when (file-exists-p file)
		 (file-attributes file)))
	 (type (w3m-local-file-type url)))
    (list (or (w3m-arrived-content-type url) (car type))
	  nil
	  (nth 7 attr)
	  (cdr type)
	  (nth 5 attr)
	  (w3m-expand-file-name-as-url (file-truename file)))))

(defun w3m-local-retrieve (url &optional no-decode &rest args)
  "Retrieve contents of local URL and put it into the current buffer.
This function will return the content-type of URL as a string when
retrieval is successful."
  (let ((file (w3m-url-to-file-name url)))
    (when (file-readable-p file)
      (if (file-directory-p file)
	  (w3m-local-dirlist-cgi url)
	(let ((coding-system-for-read 'binary)
	      (file-coding-system-for-read 'binary))
	  (if no-decode
	      (let (jka-compr-compression-info-list
		    jam-zcat-filename-list
		    format-alist)
		(insert-file-contents file))
	    (insert-file-contents file))))
      (or (w3m-arrived-content-type url)
	  (w3m-local-content-type file)))))

(defun w3m-local-dirlist-cgi (url)
  (w3m-message "Reading %s..." url)
  (if w3m-dirlist-cgi-program
      (if (file-executable-p w3m-dirlist-cgi-program)
	  (let ((coding-system-for-read 'binary)
		(default-process-coding-system
		  (cons 'binary 'binary))
		(lcookie (make-temp-name
			  (format "%s.%d." (user-login-name) (emacs-pid))))
		(cfile (make-temp-name
			(expand-file-name "w3melck" w3m-profile-directory)))
		file beg end)
	    (with-temp-buffer
	      (insert lcookie)
	      (write-region (point-min) (point-max) cfile 'nomsg))
	    (w3m-process-with-environment
		(list
		 (cons "LOCAL_COOKIE" lcookie)
		 (cons "LOCAL_COOKIE_FILE" cfile)
		 (cons "QUERY_STRING"
		       (format
			"dir=%s&cookie=%s"
			(encode-coding-string (w3m-url-to-file-name url)
					      w3m-file-name-coding-system)
			lcookie)))
	      (call-process w3m-dirlist-cgi-program nil t nil))
	    ;; delete local cookie file
	    (when (and (file-exists-p cfile) (file-writable-p cfile))
	      (delete-file cfile))
	    (goto-char (point-min))
	    (when (re-search-forward "^<html>" nil t)
	      (delete-region (point-min) (match-beginning 0))
	      (while (re-search-forward
		      "<a href=\"\\([^\"]+\\)\"\\(>\\| \\)" nil t)
		(setq file (match-string 1))
		(setq beg (match-beginning 1))
		(setq end (match-end 1))
		(if (file-directory-p file)
		    (setq file (w3m-expand-file-name-as-url
				(file-name-as-directory file)))
		  (setq file (w3m-expand-file-name-as-url file)))
		(delete-region beg end)
		(goto-char beg)
		(insert (encode-coding-string
			 (w3m-url-decode-string file
						w3m-file-name-coding-system)
			 w3m-file-name-coding-system)))))
	(error "Can't execute: %s" w3m-dirlist-cgi-program))
    ;; execute w3m internal CGI
    (w3m-process-with-wait-handler
      (setq w3m-current-url url)
      (w3m-process-start handler
			 w3m-command
			 (append w3m-command-arguments
				 (list "-dump_source" url)))))
  ;; bind charset to w3m-file-name-coding-system
  (let ((charset (or (car (rassq w3m-file-name-coding-system
				 w3m-charset-coding-system-alist))
		     w3m-file-name-coding-system))
	beg)
    (goto-char (point-min))
    (when (search-forward "<head>" nil t)
      (insert "\n<meta http-equiv=\"CONTENT-TYPE\" "
	      "content=\"text/html; charset="
	      (symbol-name charset)
	      "\">"))
    (goto-char (point-min))
    ;; Remove <form>...</form>
    (when (search-forward "<form " nil t)
      (setq beg (match-beginning 0))
      (when (search-forward "</form>" nil t)
	(delete-region beg (match-end 0)))))
  (w3m-message "Reading %s...done" url))

;;; Retrieving data via HTTP:
(defun w3m-remove-redundant-spaces (str)
  "Remove leading and trailing whitespace from STR."
  (save-match-data
    (when (string-match "\\`[ \t\r\f\n]+" str)
      (setq str (substring str (match-end 0))))
    (if (string-match "[ \t\r\f\n]+\\'" str)
	(substring str 0 (match-beginning 0))
      str)))

(defun w3m-w3m-parse-header (url header)
  "Parse a given string HEADER as a MIME header of URL.
Return a list which includes:

 0. Status code.
 1. Type of contents.
 2. Charset of contents.
 3. Size in bytes.
 4. Encoding of contents.
 5. Last modification time.
 6. Real URL.
"
  (let ((case-fold-search t)
	(headers)
	(status))
    (dolist (line (split-string header "[ \f\t\r]*\n"))
      (cond
       ((string-match "\\`HTTP/1\\.[0-9] \\([0-9][0-9][0-9]\\)\\b" line)
	(setq status (string-to-number (match-string 1 line))))
       ((string-match (eval-when-compile
			(concat "\\`\\("
				(regexp-opt
				 '(;; MEMO: $B%U%!%$%k$r%@%&%s%m!<%I$9$k(B
				   ;; $B$H$-$N(B $BE,@Z$J%G%U%)%k%HL>$r7hDj(B
				   ;; $B$9$k$?$a$K$O(B content-disposition
				   ;; $B$N2r<a$,I,MW!%(B
				   "content-disposition"
				   "content-encoding"
				   "content-length"
				   ;; MEMO: See [emacs-w3m:02341].
				   "content-transfer-encoding"
				   "content-type"
				   "last-modified"
				   "location"
				   "w3m-current-url"
				   "w3m-ssl-certificate"
				   "x-w3m-content-encoding"))
				"\\):[ \t]*"))
		      line)
	(push (cons (downcase (match-string 1 line))
		    (substring line (match-end 0)))
	      headers))))
    (let (type charset)
      (when (setq type (cdr (assoc "content-type" headers)))
	(if (string-match ";[ \t]*charset=\"?\\([^\"]+\\)\"?" type)
	    (setq charset (w3m-remove-redundant-spaces
			   (match-string 1 type))
		  type (w3m-remove-redundant-spaces
			(substring type 0 (match-beginning 0))))
	  (setq type (w3m-remove-redundant-spaces type))
	  (when (string-match ";" type)
	    (setq type (substring type 0 (match-beginning 0)))))
	(setq type (downcase type)))
      (setq w3m-current-ssl (cdr (assoc "w3m-ssl-certificate" headers)))
      (list status
	    (or type (w3m-local-content-type url))
	    (or charset
		(and (eq w3m-type 'w3mmee)
		     (setq charset
			   (cdr (assoc "w3m-document-charset" headers)))
		     (car (split-string charset))))
	    (let ((v (cdr (assoc "content-length" headers))))
	      (and v (setq v (string-to-number v)) (> v 0) v))
	    (cdr (or (assoc "content-encoding" headers)
		     (when (eq w3m-type 'w3mmee)
		       (assoc "x-w3m-content-encoding" headers))))
	    (let ((v (cdr (assoc "last-modified" headers))))
	      (and v (w3m-time-parse-string v)))
	    (or (when (string-match "\\`ftps?:" url)
		  (cdr (assoc "w3m-current-url" headers)))
		(let ((v (cdr (assoc "location" headers))))
		  ;; RFC2616 says that the field value of the Location
		  ;; response-header consists of a single absolute
		  ;; URI.  However, some broken servers return
		  ;; relative URIs.
		  (and v (w3m-expand-url v url)))
		url)))))

(defun w3m-w3m-dump-head (url handler)
  "Return the header string of URL."
  (lexical-let ((url url))
    (w3m-message "Request sent, waiting for response...")
    (w3m-process-do-with-temp-buffer
	(success (progn
		   (setq w3m-current-url url
			 url (w3m-url-strip-authinfo url))
		   (w3m-process-start handler
				      w3m-command
				      (append w3m-command-arguments
					      (list "-o" "follow_redirection=0"
						    "-dump_head" url)))))
      (w3m-message "Request sent, waiting for response...done")
      (when success
	(buffer-string)))))

(defsubst w3m-w3m-canonicalize-url (url)
  "Add a slash to an URL, when its server part is not ended with a slash."
  ;; Because URLs encountered in WEB documents are no less reliable
  ;; than URLs given by users, a minimum canonicalization may be
  ;; required in the backend side.  For more detail, please see
  ;; [emacs-w3m:07000].
  (if (string-match "\\`\\(ht\\|f\\)tps?://[^/]+\\'" url)
      (concat url "/")
    url))

(defun w3m-w3m-attributes (url no-cache handler)
  "Return a list of attributes corresponding to URL.
Return nil if it failed in retrieving of the header.
Otherwise, return a list which includes the following elements:

 0. Type of contents.
 1. Charset of contents.
 2. Size in bytes.
 3. Encoding of contents.
 4. Last modification time.
 5. Real URL.

If the optional argument NO-CACHE is non-nil, cache is not used."
  (w3m-w3m-attributes-1 (w3m-w3m-canonicalize-url url)
			no-cache
			(or w3m-follow-redirection 0)
			handler))

(defun w3m-w3m-attributes-1 (url no-cache counter handler)
  "A subroutine for `w3m-w3m-attributes'."
  (lexical-let ((url url)
		(no-cache no-cache)
		(counter counter))
    (w3m-process-do
	(header (or (unless no-cache
		      (w3m-cache-request-header url))
		    (w3m-w3m-dump-head url handler)))
      (when header
	(let ((attr (w3m-w3m-parse-header url header)))
	  (if (string-match "\\`ftps?:" url)
	      (progn
		(setq url (nth 6 attr))
		(if (string-match "/\\'" url)
		    (list "text/html"
			  (if w3m-accept-japanese-characters
			      "w3m-euc-japan" "w3m-iso-latin-1")
			  nil nil nil url)
		  (list (w3m-local-content-type url) nil nil nil nil url)))
	    (w3m-cache-header url header)
	    (if (memq (car attr) '(300 301 302 303 304 305 306 307))
		(if (zerop counter)
		    ;; Redirect counter exceeds `w3m-follow-redirection'.
		    nil
		  ;; Follow redirection.
		  (w3m-w3m-attributes-1 (nth 6 attr) no-cache
					(1- counter) handler))
	      (cdr attr))))))))

(defun w3m-w3m-expand-arguments (arguments)
  (apply 'append
	 (mapcar
	  (lambda (x)
	    (cond
	     ((stringp x) (list x))
	     ((setq x (eval x))
	      (cond ((stringp x)
		     (list x))
		    ((listp x)
		     (w3m-w3m-expand-arguments x))
		    (t
		     (let (print-level print-length)
		       (list (prin1-to-string x))))))))
		arguments)))

(defun w3m-w3m-dump-extra (url handler)
  "Retrive headers and contents pointed to by URL"
  (lexical-let ((url url))
    (setq w3m-current-url url
	  url (w3m-url-strip-authinfo url))
    (w3m-message "Reading %s...%s"
		 url
		 (if (and w3m-async-exec (not w3m-process-waited))
		     (substitute-command-keys "\
 (Type `\\<w3m-mode-map>\\[w3m-process-stop]' to stop asynchronous process)")
		   ""))
    (w3m-process-do
	(success
	 (w3m-process-start handler
			    w3m-command
			    (append w3m-command-arguments
				    (w3m-w3m-expand-arguments
				     w3m-dump-head-source-command-arguments)
				    (list url))))
      (w3m-message "Reading %s...done" url)
      (when success
	(goto-char (point-min))
	(let ((case-fold-search t))
	  (when (and (re-search-forward "^w3m-current-url:" nil t)
		     (progn
		       (delete-region (point-min) (match-beginning 0))
		       (search-forward "\n\n" nil t)))
	    ;; Asahi-shimbun sometimes says gif as jpeg mistakenly, for
	    ;; example.  So, we cannot help trusting the data itself.
	    (when (prog2
		      (setq case-fold-search nil)
		      (looking-at "\\(GIF8\\)\\|\\(\377\330\\)\\|\211PNG\r\n")
		    (setq case-fold-search t))
	      (let ((type (cond ((match-beginning 1) "gif")
				((match-beginning 2) "jpeg")
				(t "png"))))
		(save-excursion
		  (when (re-search-backward "^content-type: image/\\(.+\\)$"
					    nil t)
		    (delete-region (goto-char (match-beginning 1))
				   (match-end 1))
		    (insert type)))))
	    (let ((header (buffer-substring (point-min) (point))))
	      (when w3m-use-cookies
		(w3m-cookie-set url (point-min) (point)))
	      (delete-region (point-min) (point))
	      (w3m-cache-header url header)
	      (w3m-cache-contents url (current-buffer))
	      (w3m-w3m-parse-header url header))))))))

(defun w3m-additional-command-arguments (url)
  "Return a list of additional arguments passed to the w3m command.
You may specify additional arguments for the particular urls using the
option `w3m-command-arguments-alist', or using `w3m-no-proxy-domains'
to add the option \"-no-proxy\"."
  (let ((defs w3m-command-arguments-alist)
	def args host)
    (while (and defs
		(null args))
      (setq def (car defs)
	    defs (cdr defs))
      (when (string-match (car def) url)
	(setq args (cdr def))))
    (when (and w3m-no-proxy-domains
	       (not (member "-no-proxy" args))
	       (string-match "^[a-z]+://\\([^/:]+\\)" url)
	       (catch 'domain-match
		 (setq host (match-string 1 url))
		 (dolist (domain w3m-no-proxy-domains)
		   (when (string-match (concat "\\(^\\|\\.\\)"
					       (regexp-quote domain)
					       "$")
				       host)
		     (throw 'domain-match t)))))
      (push "-no-proxy" args))
    args))

(defun w3m-add-referer-p (url referer)
  "Return non-nil when URL and REFERER satisfies the condition
specified by `w3m-add-referer'."
  (when (stringp referer)
    (cond
     ((eq w3m-add-referer 'lambda)
      (let (host)
	(when (and (string-match w3m-url-components-regexp url)
		   (match-beginning 4))
	  (setq host (match-string 4 url))
	  (when (and (string-match w3m-url-components-regexp referer)
		     (match-beginning 4))
	    (string= host (match-string 4 referer))))))
     ((consp w3m-add-referer)
      (and (not (and (cdr w3m-add-referer)
		     (string-match (cdr w3m-add-referer) referer)))
	   (car w3m-add-referer)
	   (string-match (car w3m-add-referer) referer)))
     ((functionp w3m-add-referer)
      (funcall w3m-add-referer url referer))
     (t w3m-add-referer))))

;; Currently, -request argument is supported only by w3mmee.
(defun w3m-request-arguments (method url temp-file
				     &optional body referer content-type)
  "Make the arguments for `-request' or `-header' option passed to w3m.
METHOD is an HTTP method name.
TEMP-FILE is a name of temporal file to write request content to.
Optional BODY is the body content string.
Second optional REFERER is the Referer: field content.
Third optional CONTENT-TYPE is the Content-Type: field content."
  (with-temp-buffer
    (let ((modes (default-file-modes))
	  (cookie (and w3m-use-cookies (w3m-cookie-get url))))
      (if (and (null cookie)(null body)
	       (null content-type))
	  (append
	   (when w3m-add-user-agent
	     (list "-header" (concat "User-Agent:" w3m-user-agent)))
	   (when (w3m-add-referer-p url referer)
	     (list "-header" (concat "Referer: " referer)))
	   (when w3m-accept-languages
	     (list "-header" (concat
			      "Accept-Language: "
			      (mapconcat 'identity w3m-accept-languages
					 " ")))))
	(when w3m-add-user-agent (insert "User-Agent: " w3m-user-agent "\n"))
	(when (w3m-add-referer-p url referer)
	  (insert "Referer: " referer "\n"))
	(when w3m-accept-languages
	  (insert "Accept-Language: "
		  (mapconcat 'identity w3m-accept-languages " ") "\n"))
	(when cookie
	  (insert "Cookie: " cookie "\n"))
	(when content-type
	  (insert "Content-Type: " content-type "\n"))
	(insert "\n")
	(when body
	  (insert body))
	(unwind-protect
	    (let ((coding-system-for-write 'binary))
	      (set-default-file-modes (* 64 6))
	      (write-region (point-min) (point-max) temp-file nil 'silent))
	  (set-default-file-modes modes))
	(list "-request" (concat method ":" temp-file))))))

;; Currently, w3m uses this function.
(defun w3m-header-arguments (method url temp-file
				    &optional body referer content-type)
  "Make the arguments for the `-header' option passed to the w3m command.
METHOD is an HTTP method name.
TEMP-FILE is a name of temporal file to write post body to.
Optional BODY is the post body content string.
Optional second REFERER is the Referer: field content.
Third optional CONTENT-TYPE is the Content-Type: field content."
  (let ((modes (default-file-modes))
	(cookie (and w3m-use-cookies (w3m-cookie-get url)))
	args)
    (when w3m-add-user-agent
      (setq args (nconc args
			(list "-o" (concat "user_agent=" w3m-user-agent)))))
    (when cookie
      (setq args (nconc args
			(list "-header" (concat "Cookie: " cookie)))))
    (when (and (string= method "post") temp-file)
      (with-temp-buffer
	(set-buffer-multibyte nil)
	(when body (insert body))
	(unwind-protect
	    (let ((coding-system-for-write 'binary))
	      (set-default-file-modes (* 64 6))
	      (write-region (point-min) (point-max) temp-file nil 'silent))
	  (set-default-file-modes modes)))
      (setq args (nconc args
			(when content-type
			  (list "-header" (concat "Content-Type: "
						  content-type)))
			(list "-post" temp-file))))
    (when (w3m-add-referer-p url referer)
      (setq args (nconc args (list "-header" (concat "Referer: " referer)))))
    args))

(defun w3m-w3m-retrieve (url no-decode no-cache post-data referer handler)
  "Retrieve web contents pointed to by URL using the external w3m command.
It will put the retrieved contents into the current buffer.  See
`w3m-retrieve' for how does it work asynchronously with the arguments."
  (lexical-let ((url (w3m-w3m-canonicalize-url url))
		(no-decode no-decode)
		(current-buffer (current-buffer)))
    (w3m-process-do-with-temp-buffer
	(attr (progn
		(set-buffer-multibyte nil)
		(w3m-w3m-retrieve-1 url post-data referer no-cache
				    (or w3m-follow-redirection 0) handler)))
      (when (eq (car attr) 200)
	(if (or no-decode
		(w3m-decode-encoded-contents (nth 4 attr)))
	    (let ((temp-buffer (current-buffer)))
	      (with-current-buffer current-buffer
		(insert-buffer-substring temp-buffer))
	      (cadr attr))
	  (ding)
	  (w3m-message "Can't decode encoded contents: %s" url)
	  nil)))))

(defun w3m-w3m-retrieve-1 (url post-data referer no-cache counter handler)
  "A subroutine for `w3m-w3m-retrieve'."
  (let ((w3m-command-arguments
	 (append w3m-command-arguments
		 (when (member "cookie" w3m-compile-options)
		   (list "-no-cookie"))
		 (list "-o" "follow_redirection=0")
		 (w3m-additional-command-arguments url)))
	(temp-file))
    (and no-cache
	 w3m-broken-proxy-cache
	 (setq w3m-command-arguments
	       (append w3m-command-arguments '("-o" "no_cache=1"))))
    (setq temp-file
	  (when (or (eq w3m-type 'w3mmee) post-data)
	    (make-temp-name
	     (expand-file-name "w3mel" w3m-profile-directory))))
    (setq w3m-command-arguments
	  (append w3m-command-arguments
		  (apply (if (eq w3m-type 'w3mmee)
			     'w3m-request-arguments
			   'w3m-header-arguments)
			 (list (if post-data "post" "get")
			       url
			       temp-file
			       (if (consp post-data)
				   (cdr post-data)
				 post-data)
			       referer
			       (if (consp post-data) (car post-data))))))
    (lexical-let ((url url)
		  (post-data post-data)
		  (referer referer)
		  (no-cache no-cache)
		  (counter counter)
		  (temp-file temp-file))
      (w3m-process-do
	  (attr (or (unless no-cache
		      (and (w3m-cache-available-p url)
			   (w3m-cache-request-contents url)
			   (w3m-w3m-parse-header
			    url (w3m-cache-request-header url))))
		    (w3m-w3m-dump-extra url handler)))
	(and temp-file
	     (file-exists-p temp-file)
	     (delete-file temp-file))
	(if (memq (car attr) '(300 301 302 303 304 305 306 307))
	    (if (zerop counter)
		;; Redirect counter exceeds `w3m-follow-redirection'.
		nil
	      ;; Follow redirection.
	      (erase-buffer)
	      (unless (and post-data
			   (cond
			    ((memq (car attr) '(301 302))
			     (if w3m-redirect-with-get
				 (setq post-data nil)
			       (not (y-or-n-p
				     (format "Send POST data to `%s'?" url)))))
			    ((eq (car attr) 303) ; => See Other
			     (setq post-data nil))
			    ((eq (car attr) 307) ; => Temporally Redirect
			     (not (y-or-n-p
				   (format "Send POST data to `%s'?" url))))))
		(w3m-w3m-retrieve-1 (nth 6 attr)
				    post-data referer no-cache
				    (1- counter) handler)))
	  attr)))))

(defun w3m-about-retrieve (url &optional no-decode no-cache
			       post-data referer handler)
  "Retrieve the about: page which is pointed to by URL.
It will put the retrieved contents into the current buffer.  See
`w3m-retrieve' for how does it work asynchronously with the arguments."
  (cond
   ((string= "about://emacs-w3m.gif" url)
    (when (or (fboundp 'base64-decode-string)
	      (condition-case nil
		  ;; Emacs 19 doesn't provide the internal base64 functions.
		  (require 'base64)
		(error
		 (message "You need to install the base64.el(c) module")
		 nil)))
      (let* ((b64d 'base64-decode-string)
	     ;; Avoid compile warning under old Emacsen.
	     (icon (funcall b64d w3m-emacs-w3m-icon)))
	(if (featurep 'xemacs)
	    (insert icon)
	  (set-buffer-multibyte (multibyte-string-p icon))
	  (insert icon)
	  (set-buffer-multibyte nil)))
      "image/gif"))
   ((string-match "\\`about://source/" url)
    (w3m-process-do
	(type (w3m-retrieve (substring url (match-end 0))
			    no-decode no-cache post-data referer handler))
      (when type "text/plain")))
   ((string-match "\\`about:/*blank/?\\'" url)
    "text/plain")
   (t
    (lexical-let ((output-buffer (current-buffer)))
      (w3m-process-do-with-temp-buffer
	  (type (let (func)
		  (setq w3m-current-url url)
		  (set-buffer-multibyte t)
		  (if (and (string-match "\\`about://\\([^/]+\\)/" url)
			   (setq func
				 (intern-soft (concat "w3m-about-"
						      (match-string 1 url))))
			   (fboundp func))
		      (funcall func url no-decode no-cache
			       post-data referer handler)
		    (w3m-about url no-decode no-cache))))
	(when type
	  (when (string-match "\\`text/" type)
	    (encode-coding-region (point-min) (point-max) w3m-coding-system))
	  (set-buffer-multibyte nil)
	  (when (buffer-name output-buffer)
	    (let ((temp-buffer (current-buffer)))
	      (with-current-buffer output-buffer
		(insert-buffer-substring temp-buffer))))
	  type))))))

(defun w3m-cid-retrieve (url &optional no-decode no-cache)
  "Retrieve contents pointed to by URL prefixed with the cid: scheme.
This function is mainly used when displaying text/html MIME parts in
message user agents, e.g., Gnus, Mew, T-gnus, Wanderlust, and possibly
VM.

It calls a function according to the `major-mode' of the buffer
specified by `w3m-current-buffer'.  Functions to be called are
specified by the `w3m-cid-retrieve-function-alist' variable.

Each function in that variable should take three arguments passed
through this function, extract and insert contents specified by URL
\(which can be found in the raw message itself) into the current buffer,
and return the content type of the data.

The optional two arguments can be omitted by functions; NO-DECODE
specifies whether functions should not decode extracted contents;
NO-CACHE specifies whether functions should not use cached contents."
  (let ((func (cdr (assq (with-current-buffer w3m-current-buffer major-mode)
			 w3m-cid-retrieve-function-alist))))
    (when func (funcall func url no-decode no-cache))))

;;;###autoload
(defun w3m-retrieve (url &optional no-decode no-cache
			 post-data referer handler)
  "Retrieve web contents pointed to by URL.
It will put the retrieved contents into the current buffer.

If HANDLER is nil, this function will retrieve web contents, return
the content type of the retrieved data, and then come to an end.  This
behavior is what is called a synchronous operation.  You have to
specify HANDLER in order to make this function show its real ability,
which is called an asynchronous operation.

If HANDLER is a function, this function will come to an end in no time.
In this case, contents will be retrieved by the asynchronous process
after a while.  And after finishing retrieving contents successfully,
HANDLER will be called on the buffer where this function starts.  The
content type of the retrieved data will be passed to HANDLER as a
string argument.

NO-DECODE specifies whether this function should not decode contents.
NO-CACHE specifies whether this function should not use cached contents.
POST-DATA and REFERER will be sent to the web server with a request."
  (if (not handler)
      (condition-case nil
	  (w3m-process-with-wait-handler
	    (w3m-retrieve url
			  no-decode no-cache post-data referer handler))
	(w3m-process-timeout nil))
    (unless (and w3m-safe-url-regexp
		 (not (string-match w3m-safe-url-regexp url)))
      (setq url (w3m-url-strip-fragment url))
      (set-buffer-multibyte nil)
      (cond
       ((string-match "\\`about:" url)
	(w3m-about-retrieve url
			    no-decode no-cache post-data referer handler))
       ((string-match "\\`cid:" url)
	(w3m-cid-retrieve url no-decode no-cache))
       ((w3m-url-local-p url)
	(w3m-local-retrieve url no-decode))
       (t
	(w3m-w3m-retrieve url
			  no-decode no-cache post-data referer handler))))))

;;;###autoload
(defun w3m-download (url &optional filename no-cache handler)
  (interactive
   (let* ((url (w3m-input-url "Download URL (default HOME): "
			      (when (stringp w3m-current-url)
				(if (string-match
				     "\\`about://\\(header\\|source\\)/"
				     w3m-current-url)
				    (substring w3m-current-url (match-end 0))
				  w3m-current-url))
			      w3m-home-page))
	  (basename (file-name-nondirectory (w3m-url-strip-query url))))
     (if (string-match "^[\t ]*$" basename)
	 (list url
	       (w3m-read-file-name (format "Download %s to: " url)
				   w3m-default-save-directory "index.html")
	       current-prefix-arg)
       (list url
	     (w3m-read-file-name (format "Download %s to: " basename)
				 w3m-default-save-directory basename)
	     current-prefix-arg))))
  (if (and w3m-use-ange-ftp (string-match "\\`ftp://" url))
      (w3m-goto-ftp-url url filename)
    (lexical-let ((url url)
		  (filename (or filename (w3m-read-file-name nil nil url))))
      (w3m-process-do-with-temp-buffer
	  (type (progn
		  (w3m-clear-local-variables)
		  (setq w3m-current-url url)
		  (w3m-retrieve url t no-cache nil nil handler)))
	(if type
	    (let ((buffer-file-coding-system 'binary)
		  (file-coding-system 'binary)
		  (coding-system-for-write 'binary)
		  jka-compr-compression-info-list
		  jam-zcat-filename-list
		  format-alist)
	      (when (or (not (file-exists-p filename))
			(y-or-n-p
			 (format "File(%s) already exists. Overwrite? "
				 filename)))
		(write-region (point-min) (point-max) filename)
		(w3m-touch-file filename (w3m-last-modified url))
		t))
	  (ding)
	  (message "Cannot retrieve URL: %s%s"
		   url
		   (if w3m-process-exit-status
		       (format " (exit status: %s)" w3m-process-exit-status)
		     ""))
	  nil)))))

(defvar w3m-touch-file-available-p 'undecided)

(defun w3m-touch-file (file time)
  "Change the access and/or modification TIME of the specified FILE."
  ;; Check the validity of `touch' command.
  (when (eq w3m-touch-file-available-p 'undecided)
    (let ((file (make-temp-name
		 (expand-file-name "w3mel" w3m-profile-directory)))
	  time timefile)
      (while (progn
	       (setq time (list (abs (% (random) 8192))
				(abs (% (random) 65536)))
		     timefile (expand-file-name
			       (format-time-string "%Y%m%d%H%M.%S" time)
			       w3m-profile-directory))
	       (file-exists-p timefile)))
      (unwind-protect
	  (setq w3m-touch-file-available-p
		(when (w3m-which-command w3m-touch-command)
		  (with-temp-buffer
		    (insert "touch check")
		    (write-region (point-min) (point-max) file nil 'nomsg))
		  (and (let ((default-directory w3m-profile-directory)
			     (w3m-touch-file-available-p t))
			 (w3m-touch-file file time))
		       (zerop (w3m-time-lapse-seconds
			       time (nth 5 (file-attributes file)))))))
	(when (file-exists-p file)
	  (ignore-errors (delete-file file)))
	(when (file-exists-p timefile)
	  (ignore-errors (delete-file timefile))))))
  (and w3m-touch-file-available-p
       time
       (w3m-which-command w3m-touch-command)
       (file-exists-p file)
       (zerop (let ((default-directory (file-name-directory file)))
		(call-process w3m-touch-command nil nil nil
			      "-t" (format-time-string "%Y%m%d%H%M.%S" time)
			      file)))))

;;; Retrieve data:
(w3m-make-ccl-coding-system
 'w3m-euc-japan ?E
 "ISO 2022 based EUC encoding for Japanese with w3m internal characters.
  (generated by `w3m')"
 'w3m-euc-japan-decoder
 'w3m-euc-japan-encoder)

(w3m-make-ccl-coding-system
 'w3m-iso-latin-1 ?1
 "ISO 2022 based 8-bit encoding for Latin-1 with w3m internal characters.
  (generated by `w3m')"
 'w3m-iso-latin-1-decoder
 'w3m-iso-latin-1-encoder)

(defun w3m-remove-comments ()
  "Remove HTML comments in the current buffer."
  (goto-char (point-min))
  (let (beg)
    (while (search-forward "<!--" nil t)
      (setq beg (match-beginning 0))
      (if (search-forward "-->" nil t)
	  (delete-region beg (point))))))

(defun w3m-check-header-tags ()
  "Process header tags (<LINK>,<BASE>) in the current buffer."
  (let ((case-fold-search t)
	tag)
    (goto-char (point-min))
    (when (re-search-forward "</head\\([ \t\r\f\n][^>]*\\)?>" nil t)
      (save-restriction
	(narrow-to-region (point-min) (point))
	(goto-char (point-min))
	(while (re-search-forward "<\\(link\\|base\\)[ \t\r\f\n]+" nil t)
	  (setq tag (downcase (match-string 1)))
	  (cond
	   ((string= tag "link")
	    (w3m-parse-attributes ((rel :case-ignore) href type)
	      (when rel
		(setq rel (split-string rel))
		(cond
		 ((member "icon" rel) (setq w3m-icon-data (cons href type)))
		 ((member "next" rel) (setq w3m-next-url href))
		 ((or (member "prev" rel) (member "previous" rel))
		  (setq w3m-previous-url href))
		 ((member "start" rel) (setq w3m-start-url href))
		 ((member "contents" rel) (setq w3m-contents-url href))))))
	   ((string= tag "base")
	    (w3m-parse-attributes (href)
	      (setq w3m-current-base-url href)))))))))

(defun w3m-check-refresh-attribute ()
  "Get REFRESH attribute in META tags."
  (setq w3m-current-refresh nil)
  (when w3m-use-refresh
    (let ((case-fold-search t)
	  sec refurl)
      (goto-char (point-min))
      (catch 'found
	(while (re-search-forward "<meta[ \t\r\f\n]+" nil t)
	  (w3m-parse-attributes ((http-equiv :case-ignore) content)
	    (when (and (string= http-equiv "refresh")
		       (string-match
			"\\([^;]+\\);[ \t\n]*url=[\"']?\\([^\"']+\\)"
			content))
	      (setq sec (match-string-no-properties 1 content))
	      (setq refurl (w3m-decode-entities-string
			    (match-string-no-properties 2 content)))
	      (when (string-match "\\`[\"']\\(.*\\)[\"']\\'" refurl)
		(setq refurl (match-string 1 refurl))
		(unless (string-match "[^0-9]" sec)
		  (throw 'found
			 (setq w3m-current-refresh
			       (cons (string-to-number sec)
				     (w3m-expand-url refurl)))))))))))))

(defun w3m-remove-meta-charset-tags ()
  (let ((case-fold-search t))
    (goto-char (point-min))
    (catch 'found
      (when (re-search-forward "<meta[ \t\r\f\n]+" nil t)
	(let ((start (match-beginning 0)))
	  (w3m-parse-attributes ((http-equiv :case-ignore)
				 (content :case-ignore))
	    (when (and (string= http-equiv "content-type")
		       content
		       (string-match ";[ \t\n]*charset=" content))
	      (delete-region start (point))
	      (throw 'found nil))))))))

(defun w3m-rendering-extract-title ()
  "Extract the title from the halfdump and put it into the current buffer."
  (goto-char (point-min))
  (or (when (re-search-forward "<title_alt[ \t\n]+title=\"\\([^\"]+\\)\">"
			       nil t)
	(prog1 (w3m-decode-entities-string
		(mapconcat 'identity
			   (save-match-data (split-string (match-string 1)))
			   " "))
	  (delete-region (match-beginning 0) (match-end 0))))
      (when (and (stringp w3m-current-url)
		 (string-match "/\\([^/]+\\)/?\\'" w3m-current-url))
	(match-string 1 w3m-current-url))
      "<no-title>"))

(defun w3m-rendering-half-dump (charset)
  ;; `charset' is used by `w3m-w3m-expand-arguments' to generate
  ;; arguments for w3mmee and w3m-m17n from `w3m-halfdump-command-arguments'.
  (let* ((coding-system-for-read w3m-output-coding-system)
	 (coding-system-for-write (if (eq 'binary w3m-input-coding-system)
				      w3m-current-coding-system
				    w3m-input-coding-system))
	 (default-process-coding-system
	   (cons coding-system-for-read coding-system-for-write)))
    (w3m-process-with-environment w3m-command-environment
      ;; `call-process-region' provided by XEmacs of versions 21.5.7
      ;; through 21.5.17 is evil.  It requires the point to have to be
      ;; in the beginning or the end of the region when the 4th arg is t.
      ;; The problem has been reported with an example as:
      ;; <URL:http://list-archive.xemacs.org/xemacs-beta/200311/msg00253.html>
      (w3m-static-if (featurep 'xemacs)
	  (goto-char (point-max)))
      (apply 'call-process-region
	     (point-min)
	     (point-max)
	     (or w3m-halfdump-command w3m-command)
	     t t nil
	     (w3m-w3m-expand-arguments
	      (append w3m-halfdump-command-arguments
		      w3m-halfdump-command-common-arguments
		      ;; Image size conscious rendering
		      (when (member "image" w3m-compile-options)
			(if (and w3m-treat-image-size
				 (or (w3m-display-graphic-p)
				     (and w3m-pixels-per-line
					  w3m-pixels-per-character)))
			    (list "-o" "display_image=on"
				  "-ppl" (number-to-string
					  (or w3m-pixels-per-line
					      (w3m-static-if
						  (featurep 'xemacs)
						  (font-height
						   (face-font 'default))
						(frame-char-height))))
				  "-ppc" (number-to-string
					  (or w3m-pixels-per-character
					      (w3m-static-if
						  (featurep 'xemacs)
						  (font-width
						   (face-font 'default))
						(frame-char-width)))))
			  (list "-o" "display_image=off")))))))))

(defun w3m-rendering-buffer (&optional charset)
  "Do rendering of contents in the currenr buffer as HTML and return title."
  (w3m-message "Rendering...")
  (w3m-remove-comments)
  (w3m-check-header-tags)
  (w3m-check-refresh-attribute)
  (unless (eq w3m-type 'w3m-m17n)
    (w3m-remove-meta-charset-tags))
  (w3m-rendering-half-dump charset)
  (w3m-message "Rendering...done")
  (w3m-rendering-extract-title))

(defun w3m-retrieve-and-render (url &optional no-cache charset
				    post-data referer handler)
  "Retrieve contents of URL and render them in the current buffer.
It returns a `w3m-process' object and comes to an end immediately.
The HANDLER function will be called when rendering is complete.  When
a new content is retrieved in the buffer, the HANDLER function will be
called with t as an argument.  Otherwise, it will be called with nil."
  (unless (and w3m-current-ssl
	       (not (string-match "\\`\\(ht\\|f\\)tps://" url))
	       (not (y-or-n-p "You are leaving secure page.  Continue? ")))
    (lexical-let ((url (w3m-url-strip-fragment url))
		  (charset charset)
		  (page-buffer (current-buffer))
		  (arrival-time (current-time)))
      (w3m-process-do-with-temp-buffer
	  (type (progn
		  (w3m-clear-local-variables)
		  (w3m-retrieve url nil no-cache post-data referer handler)))
	(when (buffer-live-p page-buffer)
	  (setq url (w3m-url-strip-authinfo url))
	  (if type
	      (let ((modified-time (w3m-last-modified url)))
		(w3m-arrived-add url nil modified-time arrival-time)
		(unless modified-time
		  (setf (w3m-arrived-last-modified url) nil))
		(let ((real (w3m-real-url url)))
		  (unless (string= url real)
		    (w3m-arrived-add url nil nil arrival-time)
		    (setf (w3m-arrived-title real)
			  (w3m-arrived-title url))
		    (setf (w3m-arrived-last-modified real)
			  (w3m-arrived-last-modified url))
		    (setq url real)))
		(prog1 (w3m-create-page url
					(or (w3m-arrived-content-type url)
					    type)
					(or charset
					    (w3m-arrived-content-charset url)
					    (w3m-content-charset url))
					page-buffer)
		  (unless (get-buffer-window page-buffer)
		    (w3m-message "The content (%s) has been retrieved in %s"
				 url (buffer-name page-buffer)))))
	    (ding)
	    (when (eq (car w3m-current-forms) t)
	      (setq w3m-current-forms (cdr w3m-current-forms)))
	    (prog1 (when (and w3m-show-error-information
			      (not (or (w3m-url-local-p url)
				       (string-match "\\`about:" url))))
		     (w3m-show-error-information url charset page-buffer))
	      (w3m-message "Cannot retrieve URL: %s%s"
			   url
			   (if w3m-process-exit-status
			       (format " (exit status: %s)"
				       w3m-process-exit-status)
			     "")))))))))

(defun w3m-show-error-information (url charset page-buffer)
  "Create and prepare the error information."
  (or (when (w3m-cache-request-contents url)
	(w3m-decode-encoded-contents (w3m-content-encoding url))
	t) ; Even if decoding is failed, use the cached contents.
      (let ((case-fold-search t)
	    (header (w3m-cache-request-header url))
	    (errmsg (format "\n<br><h1>Cannot retrieve URL: %s%s</h1>"
			    (format "<a href=\"%s\">%s</a>" url url)
			    (when w3m-process-exit-status
			      (format " (exit status: %s)"
				      w3m-process-exit-status)))))
	(if (or (null header)
		(string-match "\\`w3m: Can't load " header))
	    (progn
	      (erase-buffer)
	      (insert
	       errmsg
	       (format "<br><br><b>%s</b> could not be found."
		       (w3m-get-server-hostname url))
	       " Please check the name, and try again."))
	  (goto-char (point-min))
	  (when (or (re-search-forward "<body>" nil t)
		    (re-search-forward "<html>" nil t))
	    (goto-char (match-end 0)))
	  (insert errmsg "<br><br><hr><br><br>")
	  (when (or (re-search-forward "</body>" nil t)
		    (re-search-forward "</html>" nil 'max))
	    (goto-char (match-end 0)))
	  (insert "\n<br><br><hr><br><br><h2>Header information</h2><br>\n<pre>"
		  header "</pre>\n"))))
  (w3m-create-page url "text/html" charset page-buffer)
  nil)

(defun w3m-prepare-content (url type charset)
  "Prepare contents in the current buffer according to TYPE.
URL is assumed to be a place where the contents come from.  CHARSET is
passed to the filter function  corresponding to TYPE if it is
specified in the `w3m-content-type-alist' variable."
  (let ((filter (nth 3 (assoc type w3m-content-type-alist))))
    (cond
     ; Filter function is specified.
     ((functionp filter) (funcall filter url type charset))
     ; Equivalent type is specified.
     ((stringp filter) filter)
     ; No filter is specified.
     ((not filter) type)
     ; Failed.
     (t ""))))

(defun w3m-create-text-page (url type charset page-buffer)
  (w3m-safe-decode-buffer url charset type)
  (setq w3m-current-url (w3m-real-url url)
	w3m-current-title
	(if (string= "text/html" type)
	    (setf (w3m-arrived-title url)
		  (w3m-rendering-buffer charset))
	  (or (when (string-match "\\`about://\\(source\\|header\\)/" url)
		(w3m-arrived-title (substring url (match-end 0))))
	      (file-name-nondirectory (if (string-match "/\\'" url)
					  (directory-file-name url)
					url)))))
  (let ((result-buffer (current-buffer)))
    (with-current-buffer page-buffer
      (let (buffer-read-only)
	(widen)
	(delete-region (point-min) (point-max))
	(insert-buffer-substring result-buffer)
	(w3m-copy-local-variables result-buffer)
	(set-buffer-file-coding-system w3m-current-coding-system)
	(when (string= "text/html" type) (w3m-fontify))
	'text-page))))

(defun w3m-create-image-page (url type charset page-buffer)
  (when (w3m-image-type-available-p (w3m-image-type type))
    (with-current-buffer page-buffer
      (let (buffer-read-only)
	(w3m-clear-local-variables)
	(setq w3m-current-url (w3m-real-url url)
	      w3m-current-title (file-name-nondirectory url))
	(widen)
	(delete-region (point-min) (point-max))
	(insert w3m-current-title)
	(w3m-add-text-properties (point-min) (point-max)
				 (list 'face 'w3m-image-face
				       'w3m-image url
				       'mouse-face 'highlight))
	'image-page))))

(defun w3m-create-page (url type charset page-buffer)
  ;; Select a content type.
  (unless (and (stringp type)
	       (assoc type w3m-content-type-alist))
    (save-window-excursion
      (pop-to-buffer (current-buffer))
      (delete-other-windows)
      (ding)
      (setq type
	    (completing-read
	     (format "Input %s's content type (default Download): "
		     (file-name-nondirectory url))
	     w3m-content-type-alist nil t))
      (setf (w3m-arrived-content-type url) type)))
  (setq type (w3m-prepare-content url type charset))
  (w3m-safe-decode-buffer url charset type)
  (setq charset (or charset w3m-current-content-charset))
  (when w3m-use-filter (w3m-filter url))
  (w3m-relationship-estimate url)
  ;; Create pages.
  (cond
   ((string-match "\\`text/" type)
    (w3m-create-text-page url type charset page-buffer))
   ((string-match "\\`image/" type)
    (w3m-create-image-page url type charset page-buffer))
   (t
    (with-current-buffer page-buffer
      (w3m-external-view url)
      'external-view))))

(defun w3m-relationship-estimate (url)
  "Estimate relationships between a page and others."
  (save-excursion
    (save-match-data
      (catch 'estimated
	(dolist (rule w3m-relationship-estimate-rules)
	  (when (apply (car rule) url (cdr rule))
	    (throw 'estimated t)))))))

(defun w3m-relationship-simple-estimate (url regexp &optional next previous
					     start contents)
  "Search relationships with given patterns
when the URL of the retrieved page matches the REGEXP."
  (when (string-match regexp url)
    (w3m-relationship-search-patterns url next previous start contents)))

(defun w3m-relationship-magicpoint-estimate (url)
  "Search relationships for pages generated by MagicPoint."
  (goto-char (point-max))
  (when (search-backward
	 "Generated by <A HREF=\"http://www.mew.org/mgp/\">MagicPoint</A>"
	 nil t)
    (goto-char (point-min))
    (w3m-relationship-search-patterns
     url
     (eval-when-compile
       (concat "<A HREF=" w3m-html-string-regexp ">\\[next&gt;\\]</A>"))
     (eval-when-compile
       (concat "<A HREF=" w3m-html-string-regexp ">\\[&lt;prev\\]</A>"))
     (eval-when-compile
       (concat "<A HREF=" w3m-html-string-regexp ">\\[&lt;&lt;start\\]</A>"))
     (eval-when-compile
       (concat "<A HREF=" w3m-html-string-regexp ">\\[index\\]</A>")))))

(defun w3m-relationship-search-patterns (url next previous
					     &optional start contents)
  "Search relationships with given patterns."
  (goto-char (point-min))
  (and next
       (re-search-forward next nil t)
       (setq w3m-next-url
	     (w3m-expand-url (or (match-string 2)
				 (match-string 3)
				 (match-string 1))
			     url))
       (goto-char (point-min)))
  (and previous
       (re-search-forward previous nil t)
       (setq w3m-previous-url
	     (w3m-expand-url (or (match-string 2)
				 (match-string 3)
				 (match-string 1))
			     url))
       (goto-char (point-min)))
  (and start
       (re-search-forward start nil t)
       (setq w3m-start-url
	     (w3m-expand-url (or (match-string 2)
				 (match-string 3)
				 (match-string 1))
			     url))
       (goto-char (point-min)))
  (and contents
       (re-search-forward contents nil t)
       (setq w3m-contents-url
	     (w3m-expand-url (or (match-string 2)
				 (match-string 3)
				 (match-string 1))
			     url))))

(defun w3m-search-name-anchor (name &optional quiet)
  (interactive "sName: ")
  (let ((pos (point-min)))
    (catch 'found
      (while (setq pos (next-single-property-change pos 'w3m-name-anchor))
	(when (member name (get-text-property pos 'w3m-name-anchor))
	  (goto-char pos)
	  (when (eolp) (forward-line))
	  (w3m-horizontal-on-screen)
	  (throw 'found t)))
      (unless quiet
	(message "No such anchor: %s" name))
      nil)))

(defun w3m-parent-page-available-p ()
  (if (null w3m-current-url)
      nil
    (save-match-data
      (string-match "[a-z]+://?[^/]+/." w3m-current-url))))

(defun w3m-view-parent-page ()
  "Attempt to move to the parent directory of the page currently displayed.
For instance, it will let you visit \"http://foo/\" if you are currently
viewing \"http://foo/bar/\"."
  (interactive)
  (if (null w3m-current-url)
      (error "w3m-current-url is not set"))
  (let (parent-url)
    ;; Check whether http://foo/bar/ or http://foo/bar
    (if (string-match "/$" w3m-current-url)
	(if (string-match "\\(.*\\)/[^/]+/$" w3m-current-url)
	    ;; http://foo/bar/ -> http://foo/
	    (setq parent-url (concat (match-string 1 w3m-current-url) "/")))
      (if (string-match "\\(.*\\)/.+$" w3m-current-url)
	  ;; http://foo/bar -> http://foo/
	  (setq parent-url (concat (match-string 1 w3m-current-url) "/"))))
    ;; Ignore "http:/"
    (if (and parent-url
	     (string-match "^[a-z]+:/+$" parent-url))
	(setq parent-url nil))
    (if parent-url
	(w3m-goto-url parent-url)
      (error "No parent page for: %s" w3m-current-url))))

(defun w3m-view-previous-page (&optional count)
  "Move back COUNT pages in the history.
If COUNT is a positive integer, move backward COUNT times in the
history.  If COUNT is a negative integer, moving forward is performed.
COUNT is treated as 1 by default if it is omitted."
  (interactive "p")
  (unless w3m-current-url
    ;; This page may have not been registered in the history since an
    ;; accident has probably occurred, so we should skip the page.
    (if (integerp count)
	(when (> count 0)
	  (decf count))
      (setq count 0)))
  (let ((hist ;; Cons of a new history element and position pointers.
	 (if (integerp count)
	     (w3m-history-backward count)
	   (w3m-history-backward)))
	;; Inhibit sprouting of a new history.
	(w3m-history-reuse-history-elements t)
	(w3m-use-refresh nil))
    (if hist
	(let ((w3m-prefer-cache t))
	  (w3m-goto-url (caar hist) nil nil
			(w3m-history-plist-get :post-data)
			(w3m-history-plist-get :referer)
			nil
			(w3m-history-element (caddr hist) t))
	  ;; Set the position pointers in the history.
	  (setcar w3m-history (cdr hist))
	  ;; Restore last position.
	  (w3m-history-restore-position))
      (message "There's no more history"))))

(defun w3m-view-next-page (&optional count)
  "Move forward COUNT pages in history.
If COUNT is a positive integer, move forward COUNT times in the
history.  If COUNT is a negative integer, moving backward is performed.
COUNT is treated as 1 by default if it is omitted."
  (interactive "p")
  (w3m-view-previous-page (if (integerp count) (- count) -1)))

(unless (fboundp 'w3m-expand-path-name)
  (if w3m-treat-drive-letter
      ;; Avoid incompatibility of drive letters.
      (defun w3m-expand-path-name (name &optional base)
	"Convert path string NAME to the canonicalized one."
	;; cygwin-mount.el destroys `expand-file-name';
	;; (expand-file-name "../index.html" "/foo/bar/") => "c:/cygwin/foo/index.html"
	(let ((inhibit-file-name-handlers '(cygwin-mount-name-hook-function
					    cygwin-mount-map-drive-hook-function))
	      (inhibit-file-name-operation 'expand-file-name)
	      path)
	  (setq path (w3m-static-if (featurep 'xemacs)
			 ;; It is ?\ by default in XEmacs on Windows native.
			 (let ((directory-sep-char ?/))
			   (expand-file-name name base))
		       (expand-file-name name base)))
	  (if (string-match "\\`.:" path)
	      (substring path (match-end 0))
	    path)))
    (defalias 'w3m-expand-path-name 'expand-file-name)))

(defconst w3m-url-hierarchical-schemes
  '("http" "https" "ftp" "ftps" "file")
  "List of schemes which may have hierarchical parts.
This list is refered to by `w3m-expand-url' to keep backward
compatibility which is described in Section 5.2 of RFC 2396.")

(defun w3m-expand-url (url &optional base)
  "Convert URL to the absolute address, and canonicalize it."
  (save-match-data
    (if base
	(if (and (string-match w3m-url-components-regexp base)
		 (match-beginning 1))
	    (and (not (match-beginning 3))
		 (member (match-string 2 base) w3m-url-hierarchical-schemes)
		 (setq base (concat
			     (substring base 0 (match-end 1))
			     "//"
			     (substring base (match-beginning 5)))))
	  (error "BASE must have a scheme part: %s" base))
      (setq base (or w3m-current-base-url
		     w3m-current-url
		     w3m-url-fallback-base)))
    (string-match w3m-url-components-regexp url)
    ;; Remove an empty fragment part.
    (when (and (match-beginning 8)
	       (= (match-beginning 9) (length url)))
      (setq url (substring url 0 (match-beginning 8)))
      (string-match w3m-url-components-regexp url))
    ;; Remove an empty query part.
    (when (and (match-beginning 6)
	       (= (match-beginning 7) (length url)))
      (setq url (substring url 0 (match-beginning 6)))
      (string-match w3m-url-components-regexp url))
    (cond
     ((match-beginning 1)
      ;; URL has a scheme part. => URL may have an absolute spec.
      (if (or (match-beginning 3)
	      (and (< (match-beginning 5) (length url))
		   (eq ?/ (aref url (match-beginning 5)))))
	  ;; URL has a net-location part or an absolute hierarchical
	  ;; part. => URL has an absolute spec.
	  url
	(let ((scheme (match-string 2 url)))
	  (if (and (member scheme w3m-url-hierarchical-schemes)
		   (string-match w3m-url-components-regexp base)
		   (equal scheme (match-string 2 base)))
	      (w3m-expand-url (substring url (match-end 1)) base)
	    url))))
     ((match-beginning 3)
      ;; URL has a net-location part. => The hierarchical part of URL
      ;; has an absolute spec.
      (string-match w3m-url-components-regexp base)
      (concat (substring base 0 (match-end 1)) url))
     ((> (match-end 5) (match-beginning 5))
      ;; URL has a hierarchical part.
      (if (eq ?/ (aref url (match-beginning 5)))
	  ;; Its first character is the slash "/". => The hierarchical
	  ;; part of URL has an absolute spec.
	  (progn
	    (string-match w3m-url-components-regexp base)
	    (concat (substring base 0 (or (match-end 3) (match-end 1)))
		    url))
	;; The hierarchical part of URL has a relative spec.
	(let ((path-end (match-end 5))
	      ;; See the following thread about a problem related to
	      ;; the use of file-name-* functions for url string:
	      ;; http://news.gmane.org/group/gmane.emacs.w3m/thread=4210
	      file-name-handler-alist)
	  (string-match w3m-url-components-regexp base)
	  (concat
	   (substring base 0 (match-beginning 5))
	   (if (member (match-string 2 base) w3m-url-hierarchical-schemes)
	       (w3m-expand-path-name
		(substring url 0 path-end)
		(file-name-directory (match-string 5 base)))
	     (substring url 0 path-end))
	   (substring url path-end)))))
     ((match-beginning 6)
      ;; URL has a query part.
      (string-match w3m-url-components-regexp base)
      (concat (file-name-directory (substring base 0 (match-end 5)))
	      url))
     (t
      ;; URL has only a fragment part.
      (string-match w3m-url-components-regexp base)
      (concat (substring base 0 (match-beginning 8))
	      url)))))

(defsubst w3m-view-this-url-1 (url reload new-session)
  (lexical-let (pos buffer newbuffer wconfig)
    (if new-session
	(let ((empty
	       ;; If a new url has the #name portion, we simply copy
	       ;; the buffer's contents to the new settion, otherwise
	       ;; creating an empty buffer.
	       (not (and (string-match w3m-url-components-regexp url)
			 (match-beginning 8)
			 (string-equal w3m-current-url
				       (substring url
						  0 (match-beginning 8)))))))
	  (setq pos (point-marker)
		buffer (w3m-copy-buffer
			nil nil w3m-view-this-url-new-session-in-background
			empty))
	  (when w3m-view-this-url-new-session-in-background
	    (set-buffer buffer))
	  (when empty
	    (w3m-display-progress-message url)))
      (setq buffer (current-buffer)))
    (let (handler)
      (w3m-process-do
	  (success
	   (save-window-excursion
	     (prog1
		 (w3m-goto-url url reload nil nil w3m-current-url handler)
	       (setq newbuffer (current-buffer)
		     wconfig (current-window-configuration)))))
	;; When the buffer's major mode has changed from the w3m-mode
	;; to another by visiting the new url (possibly a local file,
	;; a mailto url, etc.), we need to make the new buffer visible.
	(when (and (eq (with-current-buffer buffer major-mode)
		       'w3m-mode)
		   (not (eq (with-current-buffer newbuffer major-mode)
			    'w3m-mode)))
	  (set-window-configuration wconfig))
	(when pos ;; The new session is created.
	  ;; Delete useless newly created buffer if it is empty.
	  (w3m-delete-buffer-if-empty buffer))
	;; FIXME: what we should actually do is to modify the `w3m-goto-url'
	;; function so that it may return a proper value, and checking it.
	(when (and pos (buffer-name (marker-buffer pos)))
	  (save-excursion
	    (set-buffer (marker-buffer pos))
	    (save-excursion
	      (goto-char pos)
	      (w3m-refontify-anchor))))))))

(defun w3m-view-this-url (&optional arg new-session)
  "Display the page pointed to by the link under point.
If ARG is the number 2 or the list of the number 16 (you may produce
this by typing `C-u' twice) or NEW-SESSION is non-nil and the link is
an anchor, this function makes a copy of the current session in
advance.  Otherwise, if ARG is non-nil, it forces to reload the url at
point."
  (interactive (if (member current-prefix-arg '(2 (16)))
		   (list nil t)
		 (list current-prefix-arg nil)))
  (let ((w3m-prefer-cache
	 (or w3m-prefer-cache
	     (string-match "\\`about://\\(db-\\)?history/" w3m-current-url)))
	act url)
    (cond
     ((setq act (w3m-action))
      (eval act))
     ((setq url (w3m-url-valid (w3m-anchor)))
      (w3m-view-this-url-1 url arg new-session))
     ((w3m-url-valid (w3m-image))
      (if (w3m-display-graphic-p)
	  (w3m-toggle-inline-image)
	(w3m-view-image)))
     ((setq url (w3m-active-region-or-url-at-point))
      (unless (eq 'quit (setq url (w3m-input-url nil url 'quit)))
	(w3m-view-this-url-1 url arg new-session)))
     (t (w3m-message "No URL at point")))))

(eval-and-compile
  (autoload 'mouse-set-point "mouse"))

(defun w3m-mouse-view-this-url (event &optional arg)
  "Follow the link under the mouse pointer."
  (interactive "e\nP")
  (mouse-set-point event)
  (w3m-view-this-url arg))

(defun w3m-open-all-links-in-new-session (start end &optional arg)
  "Open all http links between START and END as new sessions.
If the page looks like Google's search result and the START point is
the beginning of a line, only the links displayed in the beginning of
lines are picked up.  If ARG is non-nil, it forces to reload all links.
If Transient Mark mode, deactivate the mark."
  (interactive "r\nP")
  (when (w3m-region-active-p)
    (w3m-deactivate-region))
  (let ((buffer (current-buffer))
	(prev start)
	(url (w3m-url-valid (w3m-anchor start)))
	urls all)
    (when url
      (setq urls (list url)))
    (save-excursion
      (goto-char start)
      (setq all (not (and (bolp)
			  w3m-current-url
			  (string-match "\\`http://\\([^/]+\\.\\)*google\\."
					w3m-current-url))))
      (while (progn
	       (w3m-next-anchor)
	       (and (> (point) prev)
		    (< (point) end)))
	(setq prev (point))
	(when (and (setq url (w3m-url-valid (w3m-anchor)))
		   (string-match "\\`https?:" url)
		   (or all
		       (bolp)))
	  (push url urls))))
    (while urls
      (setq url (car urls)
	    urls (cdr urls))
      (set-buffer buffer)
      (w3m-view-this-url-1 url arg t))))

(defun w3m-view-this-url-new-session ()
  "Display the page of the link under point in a new session.
If the region is active, use the `w3m-open-all-links-in-new-session'
command instead."
  (interactive)
  (if (w3m-region-active-p)
      (call-interactively 'w3m-open-all-links-in-new-session)
    (w3m-view-this-url nil t)))

(defun w3m-mouse-view-this-url-new-session (event)
  "Follow the link under the mouse pointer in a new session."
  (interactive "e")
  (mouse-set-point event)
  (w3m-view-this-url nil t))

(defun w3m-submit-form ()
  "Submit the form at point."
  (interactive)
  (let ((submit (w3m-submit)))
    (if (and submit
	     w3m-current-url
	     (w3m-url-valid w3m-current-url))
	(eval submit)
      (w3m-message "Can't submit form at this point"))))

(defun w3m-external-view (url &optional no-cache handler)
  (when (w3m-url-valid url)
    (lexical-let ((url url)
		  (no-cache no-cache))
      (w3m-process-do
	  (type (w3m-content-type url no-cache handler))
	(when type
	  (lexical-let ((method (nth 2 (assoc type w3m-content-type-alist))))
	    (cond
	     ((not method)
	      (if (w3m-url-local-p url)
		  (error "\
No method to view `%s' is registered. Use `w3m-edit-this-url'"
			 (file-name-nondirectory (w3m-url-to-file-name url)))
		(w3m-download url nil no-cache handler)))
	     ((functionp method)
	      (funcall method url))
	     ((consp method)
	      (lexical-let
		  ((command (w3m-which-command (car method)))
		   (arguments (cdr method))
		   (file (make-temp-name
			  (expand-file-name "w3mel" w3m-profile-directory)))
		   suffix)
		(setq suffix (file-name-nondirectory url))
		(when (string-match "\\.[a-zA-Z0-9]+$" suffix)
		  (setq suffix (match-string 0 suffix))
		  (when (< (length suffix) 5)
		    (setq file (concat file suffix))))
		(cond
		 ((and command (memq 'file arguments))
		  (w3m-process-do
		      (success (w3m-download url file no-cache handler))
		    (when success
		      (w3m-external-view-file command file url arguments))))
		 (command
		  (w3m-external-view-file command nil url arguments))
		 (t
		  (w3m-download url nil no-cache handler))))))))))))

(defun w3m-external-view-file (command file url arguments)
  ;; The 3rd argument `url' is necessary to handle the constant `url'
  ;; included in the 4th argument `arguments' which is provided by
  ;; `w3m-content-type-alist'.
  (lexical-let ((file file))
    (let (proc)
      (unwind-protect
	  (with-current-buffer
	      (generate-new-buffer " *w3m-external-view*")
	    (setq proc
		  (apply 'start-process
			 "w3m-external-view"
			 (current-buffer)
			 command
			 (mapcar (function eval) arguments)))
	    (w3m-message "Start %s..." (file-name-nondirectory command))
	    (set-process-sentinel
	     proc
	     (lambda (proc event)
	       (and (string-match "^\\(finished\\|exited\\)" event)
		    (buffer-name (process-buffer proc))
		    (with-current-buffer (process-buffer proc)
		      (and (stringp file)
			   (file-exists-p file)
			   (delete-file file)))
		    (kill-buffer (process-buffer proc))))))
	(and (stringp file)
	     (file-exists-p file)
	     (unless (and (processp proc)
			  (memq (process-status proc) '(run stop)))
	       (delete-file file)))))))

(defun w3m-view-image ()
  "Display the image under point in the external viewer.
The viewer is defined in `w3m-content-type-alist' for every type of an
image."
  (interactive)
  (let ((url (w3m-url-valid (w3m-image))))
    (if url
	(w3m-external-view url)
      (w3m-message "No image at point"))))

(defun w3m-save-image ()
  "Save the image under point to a file.
The default name will be the original name of the image."
  (interactive)
  (let ((url (w3m-url-valid (w3m-image))))
    (if url
	(w3m-download url)
      (w3m-message "No image at point"))))

(defun w3m-view-url-with-external-browser ()
  "Launch the external browser and display the same web page.
The browser is defined in `w3m-content-type-alist' for every type of a
url."
  (interactive)
  (let ((url (or (w3m-anchor)
		 (unless w3m-display-inline-images
		   (w3m-image))
		 (when (y-or-n-p (format "Browse <%s> ? " w3m-current-url))
		   w3m-current-url))))
    (if (w3m-url-valid url)
	(progn
	  (message "Browsing <%s>..." url)
	  (w3m-external-view url))
      (w3m-message "No URL at point"))))

(defun w3m-download-this-url ()
  "Download the file or the page pointed to by the link under point."
  (interactive)
  (let ((url (or (w3m-anchor) (w3m-image))))
    (if (w3m-url-valid url)
	(lexical-let ((pos (point-marker))
		      (curl w3m-current-url))
	  (w3m-process-with-null-handler
	    (w3m-process-do
		(success (w3m-download url nil nil handler))
	      (and success
		   (buffer-name (marker-buffer pos))
		   (save-excursion
		     (set-buffer (marker-buffer pos))
		     (when (equal curl w3m-current-url)
		       (goto-char pos)
		       (w3m-refontify-anchor)))))))
      (w3m-message "No URL at point"))))

(defun w3m-print-current-url ()
  "Display the current url in the echo area and put it into `kill-ring'."
  (interactive)
  (when w3m-current-url
    (kill-new w3m-current-url)
    (w3m-message "%s" w3m-current-url)))

(defun w3m-print-this-url (&optional interactive-p)
  "Display the url under point in the echo area and put it into `kill-ring'."
  (interactive (list t))
  (let ((url (if interactive-p
		 (or (w3m-anchor) (w3m-image))
	       (or (w3m-anchor (point)) (w3m-image (point))))))
    (when (or url interactive-p)
      (and url interactive-p (kill-new url))
      (w3m-message "%s"
		   (or url
		       (and (w3m-action) "There is a form")
		       "There is no url")))))

(defmacro w3m-delete-all-overlays ()
  "Delete all momentary overlays."
  '(dolist (overlay (overlays-in (point-min) (point-max)))
     (if (overlay-get overlay 'w3m-momentary-overlay)
	 (delete-overlay overlay))))

(defun w3m-highlight-current-anchor-1 (seq)
  "Highlight an anchor in the line if the anchor sequence is the same as SEQ.
Return t if highlighting is successful."
  (let ((limit (save-excursion (end-of-line)
			       (point)))
	ov beg pos pseq)
    (save-excursion
      (beginning-of-line)
      (setq pos (point))
      (while (and pos
		  (< pos limit)
		  (not (eq seq (setq pseq (w3m-anchor-sequence pos)))))
	(setq pos (next-single-property-change pos 'w3m-anchor-sequence)))
      (when (and pos (< pos limit) (eq seq pseq))
	(setq beg pos)
	(setq pos (next-single-property-change pos 'w3m-anchor-sequence))
	(setq ov (make-overlay beg pos))
	(overlay-put ov 'face 'w3m-current-anchor-face)
	(overlay-put ov 'w3m-momentary-overlay t)
	(overlay-put ov 'evaporate t)
	t))))

(defun w3m-highlight-current-anchor ()
  "Highlight an anchor under point."
  (when (let ((ovs (overlays-at (point))) ov)
	  ;; If the anchor is already highlighted, it does nothing.
	  (or (null ovs)
	      (null (progn (while ovs
			     (if (overlay-get (car ovs) 'w3m-momentary-overlay)
				 (setq ov (car ovs)
				       ovs nil))
			     (setq ovs (cdr ovs)))
			   ov))))
    (w3m-delete-all-overlays)
    (save-excursion
      (let ((seq (w3m-anchor-sequence))
	    (pos (point)))
	(when (and seq
		   (w3m-highlight-current-anchor-1 seq)
		   (zerop (forward-line 1)))
	  (while (and (w3m-highlight-current-anchor-1 seq)
		      (zerop (forward-line 1))))
	  (goto-char pos)
	  (while (and (zerop (forward-line -1))
		      (w3m-highlight-current-anchor-1 seq))))))))

(defun w3m-edit-url (url)
  "Edit the page pointed by URL."
  (interactive (list (w3m-input-url)))
  (when (string-match "\\`about://\\(header\\|source\\)/" url)
    (setq url (substring url (match-end 0))))
  (catch 'found
    (dolist (pair w3m-edit-function-alist)
      (when (and (string-match (car pair) url)
		 (fboundp (cdr pair)))
	(throw 'found (funcall (cdr pair) url))))
    (funcall w3m-edit-function
	     (or (w3m-url-to-file-name url)
		 (error "URL:%s is not a local file" url)))))

(defun w3m-edit-current-url ()
  "Edit this viewing page."
  (interactive)
  (if w3m-current-url
      (w3m-edit-url w3m-current-url)
    (w3m-message "No URL")))

(defun w3m-edit-this-url ()
  "Edit the page linked from the anchor under the cursor."
  (interactive)
  (let ((url (w3m-url-valid (w3m-anchor))))
    (if url
	(w3m-edit-url url)
      (w3m-message "No URL at point"))))

(defvar w3m-goto-anchor-hist nil)
(make-variable-buffer-local 'w3m-goto-anchor-hist)

(defun w3m-goto-next-anchor ()
  (let ((hseq (w3m-anchor-sequence))
	(pos (next-single-property-change (point) 'w3m-anchor-sequence)))
    (if (or (not hseq) (< hseq 1))
	(and pos (goto-char pos))
      (setq pos
	    ;; hseq is not sequence in form.
	    (catch 'loop
	      (setq hseq (1+ hseq))
	      (while (<= hseq w3m-max-anchor-sequence)
		(setq pos (text-property-any
			   (point-min) (point-max) 'w3m-anchor-sequence hseq))
		(when pos (throw 'loop pos))
		(setq hseq (1+ hseq)))))
      (and pos (goto-char pos)))))

(defun w3m-next-anchor (&optional arg)
  "Move the point to the next anchor."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command '(w3m-next-anchor w3m-previous-anchor)))
      (when (setq w3m-goto-anchor-hist (w3m-anchor-sequence))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-previous-anchor) w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-previous-anchor (- arg))
    (while (> arg 0)
      (unless (w3m-goto-next-anchor)
	(setq w3m-goto-anchor-hist nil)
	(if (w3m-imitate-widget-button)
	    (widget-forward 1)
	  ;; Make a search from the beginning of the buffer.
	  (goto-char (point-min))
	  (w3m-goto-next-anchor)))
      (setq arg (1- arg))
      (if (member (w3m-anchor-sequence) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-anchor-sequence) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-goto-previous-anchor ()
  (let ((hseq (w3m-anchor-sequence))
	(pos (previous-single-property-change (point) 'w3m-anchor-sequence)))
    (cond
     ((and (not hseq) pos)
      (if (w3m-anchor-sequence pos)
	  (goto-char pos)
	(setq pos (previous-single-property-change pos 'w3m-anchor-sequence))
	(and pos (goto-char pos))))
     ((or (not pos) (< hseq 2)) nil)
     (t
      (setq pos
	    ;; hseq is not sequence in form.
	    (catch 'loop
	      (setq hseq (1- hseq))
	      (while (> hseq 0)
		(setq pos (text-property-any
			   (point-min) (point-max) 'w3m-anchor-sequence hseq))
		(when pos (throw 'loop pos))
		(setq hseq (1- hseq)))))
      (and pos (goto-char pos))))))

(defun w3m-previous-anchor (&optional arg)
  "Move the point to the previous anchor."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command '(w3m-next-anchor w3m-previous-anchor)))
      (when (setq w3m-goto-anchor-hist (w3m-anchor-sequence))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-next-anchor) w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-next-anchor (- arg))
    (while (> arg 0)
      (unless (w3m-goto-previous-anchor)
	(setq w3m-goto-anchor-hist nil)
	(if (w3m-imitate-widget-button)
	    (widget-forward -1)
	  ;; Make a search from the end of the buffer.
	  (goto-char (point-max))
	  (w3m-goto-previous-anchor)))
      (setq arg (1- arg))
      (if (member (w3m-anchor-sequence) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-anchor-sequence) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-goto-next-form ()
  ;; Move the point to the end of the current form.
  (when (w3m-action (point))
    (goto-char (next-single-property-change (point) 'w3m-action)))
  ;; Find the next form.
  (or (w3m-action (point))
      (let ((pos (next-single-property-change (point) 'w3m-action)))
	(when pos
	  (goto-char pos)
	  t))))

(defun w3m-next-form (&optional arg)
  "Move the point to the next form."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command '(w3m-next-form w3m-previous-form)))
      (when (setq w3m-goto-anchor-hist (w3m-action (point)))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-previous-form) w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-previous-form (- arg))
    (while (> arg 0)
      (unless (w3m-goto-next-form)
	;; Make a search from the beginning of the buffer.
	(setq w3m-goto-anchor-hist nil)
	(goto-char (point-min))
	(w3m-goto-next-form))
      (setq arg (1- arg))
      (if (member (w3m-action (point)) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-action (point)) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-goto-previous-form ()
  ;; Move the point to the beginning of the current form.
  (when (w3m-action (point))
    (goto-char (previous-single-property-change (1+ (point))
						'w3m-action)))
  ;; Find the previous form.
  (let ((pos (previous-single-property-change (point) 'w3m-action)))
    (if pos
	(goto-char
	 (if (w3m-action pos)
	     pos
	   (previous-single-property-change pos 'w3m-action))))))

(defun w3m-previous-form (&optional arg)
  "Move the point to the previous form."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command '(w3m-next-form w3m-previous-form)))
      (when (setq w3m-goto-anchor-hist (w3m-action (point)))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-next-form) w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-next-form (- arg))
    (while (> arg 0)
      (unless (w3m-goto-previous-form)
	;; search from the end of the buffer
	(setq w3m-goto-anchor-hist nil)
	(goto-char (point-max))
	(w3m-goto-previous-form))
      (setq arg (1- arg))
      (if (member (w3m-action (point)) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-action (point)) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-goto-next-image ()
  ;; Move the point to the end of the current image.
  (when (w3m-image (point))
    (goto-char (next-single-property-change (point) 'w3m-image)))
  ;; Find the next form or image.
  (or (w3m-image (point))
      (let ((pos (next-single-property-change (point) 'w3m-image)))
	(when pos
	  (goto-char pos)
	  t))))

(defun w3m-next-image (&optional arg)
  "Move the point to the next image."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command
		  '(w3m-next-image w3m-previous-image)))
      (when (setq w3m-goto-anchor-hist (w3m-image (point)))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-previous-image)
	       w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-previous-image (- arg))
    (while (> arg 0)
      (unless (w3m-goto-next-image)
	;; Make a search for an image from the beginning of the buffer.
	(setq w3m-goto-anchor-hist nil)
	(goto-char (point-min))
	(w3m-goto-next-image))
      (setq arg (1- arg))
      (if (member (w3m-image (point)) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-image (point)) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-goto-previous-image ()
  ;; Move the point to the beginning of the current image.
  (when (w3m-image (point))
    (goto-char (previous-single-property-change (1+ (point))
						'w3m-image)))
  ;; Find the previous form or image.
  (let ((pos (previous-single-property-change (point) 'w3m-image)))
    (if pos
	(goto-char
	 (if (w3m-image pos) pos
	   (previous-single-property-change pos 'w3m-image))))))

(defun w3m-previous-image (&optional arg)
  "Move the point to the previous image."
  (interactive "p")
  (w3m-keep-region-active)
  (unless arg (setq arg 1))
  (if (null (memq last-command '(w3m-next-image w3m-previous-image)))
      (when (setq w3m-goto-anchor-hist (w3m-image (point)))
	(setq w3m-goto-anchor-hist (list w3m-goto-anchor-hist)))
    (when (and (eq last-command 'w3m-next-image)
	       w3m-goto-anchor-hist)
      (setcdr w3m-goto-anchor-hist nil)))
  (if (< arg 0)
      (w3m-next-image (- arg))
    (while (> arg 0)
      (unless (w3m-goto-previous-image)
	;; Make a search from the end of the buffer.
	(setq w3m-goto-anchor-hist nil)
	(goto-char (point-max))
	(w3m-goto-previous-image))
      (setq arg (1- arg))
      (if (member (w3m-image (point)) w3m-goto-anchor-hist)
	  (setq arg (1+ arg))
	(push (w3m-image (point)) w3m-goto-anchor-hist)))
    (w3m-horizontal-on-screen)
    (w3m-print-this-url)))

(defun w3m-copy-buffer (&optional buffer newname just-copy empty)
  "Create a copy of the BUFFER in which emacs-w3m is working.
Return a new buffer.

If BUFFER is nil, the current buffer is assumed.  If NEWNAME is nil,
it defaults to the name of the current buffer.  If JUST-COPY is nil,
this function lets a new buffer be the current buffer and pop up as a
new window or a new frame according to `w3m-pop-up-windows' and
`w3m-pop-up-frames' (which see), otherwise just creates BUFFER's copy.
If EMPTY is nil, a page of the same url will be re-rendered in a new
buffer, otherwise an empty buffer is created.

Note that this function should be called on the window displaying the
original buffer BUFFER even if JUST-COPY is non-nil in order to render
a page in a new buffer with the correct width."
  (interactive (list (current-buffer)
		     (if current-prefix-arg (read-string "Name: "))))
  (unless buffer
    (setq buffer (current-buffer)))
  (unless newname
    (setq newname (buffer-name buffer)))
  (when (string-match "<[0-9]+>\\'" newname)
    (setq newname (substring newname 0 (match-beginning 0))))
  (let (url images init-frames new)
    (save-current-buffer
      (set-buffer buffer)
      (setq url (or w3m-current-url
		    (car (w3m-history-element (cadar w3m-history))))
	    images w3m-display-inline-images
	    init-frames (when (w3m-popup-frame-p)
			  (copy-sequence w3m-initial-frames)))
      ;;
      (set-buffer (setq new (generate-new-buffer newname)))
      (w3m-mode)
      (if w3m-toggle-inline-images-permanently
	  (setq w3m-display-inline-images images)
	(setq w3m-display-inline-images w3m-default-display-inline-images))
      ;; Make copies of `w3m-history' and `w3m-history-flat'.
      (w3m-history-copy buffer)
      (setq w3m-initial-frames init-frames)
      (when empty
	(w3m-clear-local-variables)))
    (if (and (not just-copy) empty)
	;; Pop to a window or a frame up because `w3m-goto-url' is not called.
	(w3m-popup-buffer new)
      ;; Need to change to the `new' buffer in which `w3m-goto-url' runs.
      (set-buffer new))
    (unless empty
      ;; Render a page.
      (let ((positions (copy-sequence (car w3m-history)))
	    (w3m-history-reuse-history-elements t)
	    (w3m-prefer-cache t))
	(w3m-process-with-wait-handler
	  (w3m-goto-url url nil nil nil nil handler
			;; Pass the properties of the history elements,
			;; although it is currently always nil.
			(w3m-history-element (cadr positions))))
	(setcar w3m-history positions)))
    new))

(defun w3m-next-buffer (arg)
  "Turn ARG pages of emacs-w3m buffers ahead."
  (interactive "p")
  (unless (zerop arg)
    (let ((buffers (if (> arg 0)
		       (w3m-list-buffers)
		     (setq arg (- arg))
		     (nreverse (w3m-list-buffers)))))
      (switch-to-buffer
       (or (nth arg (memq (current-buffer) buffers))
	   (nth (1- arg) buffers))))
    (run-hooks 'w3m-select-buffer-hook)
    (w3m-select-buffer-update)))

(defun w3m-previous-buffer (arg)
  "Turn ARG pages of emacs-w3m buffers behind."
  (interactive "p")
  (w3m-next-buffer (- arg)))

(defun w3m-delete-buffer (&optional force)
  "Delete the current emacs-w3m buffer and switch to the previous one.
If there is the sole emacs-w3m buffer, it is assumed to be called for
terminating the emacs-w3m session; the prefix argument FORCE will be
passed to the `w3m-quit' function (which see)."
  (interactive "P")
  (let* ((buffers (w3m-list-buffers t))
	 (num (length buffers))
	 cur buf bufs)
    (if (= 1 num)
	(w3m-quit force)
      (setq cur (current-buffer))
      (if (w3m-use-tab-p)
	  (w3m-next-buffer -1)
	;; List buffers being shown in the other windows of the current frame.
	(save-current-buffer
	  (walk-windows (lambda (window)
			  (set-buffer (setq buf (window-buffer window)))
			  (when (and (eq major-mode 'w3m-mode)
				     (not (eq buf cur)))
			    (push buf bufs)))
			'no-minibuf))
	(cond ((= (1- num) (length bufs))
	       ;; All the other buffers are shown in the current frame.
	       (select-window (get-buffer-window (prog2
						     (w3m-next-buffer -1)
						     (current-buffer)
						   (delete-window)))))
	      (bufs
	       ;; Look for the buffer which is not shown in the current frame.
	       (setq buf nil)
	       (while (progn
			(w3m-next-buffer -1)
			(unless buf
			  (setq buf (current-buffer)))
			(memq (current-buffer) bufs)))
	       (when (memq buf bufs)
		 ;; Go to the buffer which is most suitable to be called
		 ;; the *previous* buffer.
		 (select-window (get-buffer-window buf))))
	      ((progn ;; List buffers being not shown anywhere.
		 (setq bufs nil)
		 (while buffers
		   (unless (get-buffer-window (setq buf (pop buffers)) t)
		     (push buf bufs)))
		 bufs)
	       (while (progn
			(w3m-next-buffer -1)
			(not (memq (current-buffer) bufs)))))
	      ((memq (selected-frame) w3m-initial-frames)
	       ;; Assume that this frame was created to show this buffer.
	       (if (one-window-p t)
		   (delete-frame)
		 (delete-window)))
	      (t
	       (if (>= num 2)
		   (w3m-next-buffer -1)
		 (unless (one-window-p t)
		   (delete-window))))))
      (w3m-process-stop cur)
      (kill-buffer cur)
      (run-hooks 'w3m-delete-buffer-hook)))
  (w3m-select-buffer-update))

(defun w3m-delete-buffer-if-empty (buffer)
  "Delete a newly created emacs-w3m buffer BUFFER if it seems unnecessary.
Some emacs-w3m commands create a buffer for the new session first, but
it may be useless if the command is invoked for visiting a local file
or a mail buffer.  This command will delete BUFFER if it is empty or
there is only a progress message.  It also deletes windows and frames
related to BUFFER."
  (with-current-buffer buffer
    (unless (or w3m-current-process
		w3m-current-url
		(not (or (zerop (buffer-size))
			 (and (get-text-property (point-min)
						 'w3m-progress-message)
			      (get-text-property (1- (point-max))
						 'w3m-progress-message)))))
      (w3m-delete-buffer t))))

(defun w3m-pack-buffer-numbers ()
  "Renumber suffixes of names of emacs-w3m buffers.
It aligns emacs-w3m buffers in order of *w3m*, *w3m<2>, *w3m*<3>,...
as if the folder command of MH performs with the -pack option."
  (interactive)
  (let ((count 1) number)
    (dolist (buffer (w3m-list-buffers))
      (setq number (w3m-buffer-number buffer))
      (when number
	(unless (eq number count)
	  (w3m-buffer-set-number buffer count))
	(incf count)))))

(defun w3m-delete-other-buffers (&optional buffer)
  "Delete emacs-w3m buffers except for BUFFER or the current buffer."
  (interactive)
  (unless buffer
    (setq buffer (current-buffer)))
  (w3m-delete-frames-and-windows buffer)
  (let ((buffers (delq buffer (w3m-list-buffers t))))
    (while buffers
      (setq buffer (pop buffers))
      (w3m-process-stop buffer)
      (kill-buffer buffer)))
  (run-hooks 'w3m-delete-buffer-hook)
  (w3m-select-buffer-update))

(defvar w3m-lynx-like-map nil
  "Lynx-like keymap used in emacs-w3m buffers.")
(unless w3m-lynx-like-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map " " 'w3m-scroll-up-or-next-url)
    (define-key map "b" 'w3m-scroll-down-or-previous-url)
    (define-key map [backspace] 'w3m-scroll-down-or-previous-url)
    (define-key map [delete] 'w3m-scroll-down-or-previous-url)
    (if (featurep 'xemacs)
	(define-key map [(shift space)] 'w3m-scroll-down-or-previous-url)
      ;; Note: It does not have an effect on Emacs 19.
      (define-key map [?\S-\ ] 'w3m-scroll-down-or-previous-url))
    (define-key map "h" 'backward-char)
    (define-key map "j" 'next-line)
    (define-key map "k" 'previous-line)
    (define-key map "l" 'forward-char)
    (define-key map "J" (lambda () (interactive) (scroll-up 1)))
    (define-key map "K" (lambda () (interactive) (scroll-down 1)))
    (define-key map "\M-g" 'goto-line)
    (define-key map "\C-?" 'w3m-scroll-down-or-previous-url)
    (define-key map "\t" 'w3m-next-anchor)
    (define-key map [tab] 'w3m-next-anchor)
    (define-key map [(shift tab)] 'w3m-previous-anchor)
    (define-key map [(shift iso-lefttab)] 'w3m-previous-anchor)
    (define-key map [down] 'w3m-next-anchor)
    (define-key map "\M-\t" 'w3m-previous-anchor)
    (define-key map [up] 'w3m-previous-anchor)
    (define-key map "\C-m" 'w3m-view-this-url)
    (define-key map [(shift return)] 'w3m-view-this-url-new-session)
    (define-key map [(shift kp-enter)] 'w3m-view-this-url-new-session)
    (define-key map [right] 'w3m-view-this-url)
    (if (featurep 'xemacs)
	(progn
	  (define-key map [(button2)] 'w3m-mouse-view-this-url)
	  (define-key map [(shift button2)]
	    'w3m-mouse-view-this-url-new-session))
      (define-key map [mouse-2] 'w3m-mouse-view-this-url)
      (define-key map [S-mouse-2] 'w3m-mouse-view-this-url-new-session))
    (define-key map "\C-c\C-@" 'w3m-history-store-position)
    (if (featurep 'xemacs)
	(define-key map [?\C-c (control space)] 'w3m-history-store-position)
      ;; `C- ' doesn't mean `C-SPC' in XEmacs.
      (define-key map [?\C-c ?\C-\ ] 'w3m-history-store-position))
    (define-key map "\C-c\C-v" 'w3m-history-restore-position)
    (define-key map [left] 'w3m-view-previous-page)
    (define-key map "B" 'w3m-view-previous-page)
    (define-key map "N" 'w3m-view-next-page)
    (define-key map "^" 'w3m-view-parent-page)
    (define-key map "d" 'w3m-download-this-url)
    (define-key map "u" 'w3m-print-this-url)
    (define-key map "I" 'w3m-view-image)
    (define-key map "\M-i" 'w3m-save-image)
    (define-key map "c" 'w3m-print-current-url)
    (define-key map "M" 'w3m-view-url-with-external-browser)
    (define-key map "G" 'w3m-goto-url-new-session)
    (define-key map "g" 'w3m-goto-url)
    (define-key map "T" 'w3m-toggle-inline-images)
    (define-key map "t" 'w3m-toggle-inline-image)
    (when (w3m-display-graphic-p)
      (define-key map "\M-[" 'w3m-zoom-out-image)
      (define-key map "\M-]" 'w3m-zoom-in-image))
    (define-key map "U" 'w3m-goto-url)
    (define-key map "V" 'w3m-goto-url)
    (define-key map "v" 'w3m-bookmark-view)
    (define-key map "q" 'w3m-close-window)
    (define-key map "Q" 'w3m-quit)
    (define-key map "\M-n" 'w3m-copy-buffer)
    (define-key map "\C-c\C-t" 'w3m-copy-buffer)
    (define-key map "\C-c\C-p" 'w3m-previous-buffer)
    (define-key map "\C-c\C-n" 'w3m-next-buffer)
    (define-key map "\C-c\C-w" 'w3m-delete-buffer)
    (define-key map "\C-c\M-w" 'w3m-delete-other-buffers)
    (define-key map "\C-c\C-s" 'w3m-select-buffer)
    (define-key map "\C-c\C-a" 'w3m-switch-buffer)
    (define-key map "r" 'w3m-redisplay-this-page)
    (define-key map "R" 'w3m-reload-this-page)
    (define-key map "?" 'describe-mode)
    (define-key map "\M-a" 'w3m-bookmark-add-this-url)
    (define-key map "\M-k" 'w3m-cookie)
    (define-key map "a" 'w3m-bookmark-add-current-url)
    (define-key map "+" 'w3m-antenna-add-current-url)
    (define-key map "]" 'w3m-next-form)
    (define-key map "[" 'w3m-previous-form)
    (define-key map "}" 'w3m-next-image)
    (define-key map "{" 'w3m-previous-image)
    (define-key map "H" 'w3m-gohome)
    (define-key map "A" 'w3m-antenna)
    (define-key map "W" 'w3m-weather)
    (define-key map "S" 'w3m-search)
    (define-key map "D" 'w3m-dtree)
    (define-key map ">" 'w3m-scroll-left)
    (define-key map "<" 'w3m-scroll-right)
    (define-key map "." 'w3m-shift-left)
    (define-key map "," 'w3m-shift-right)
    (define-key map "\M-l" 'w3m-horizontal-recenter)
    (define-key map "\C-a" 'w3m-beginning-of-line)
    (define-key map "\C-e" 'w3m-end-of-line)
    (define-key map "\\" 'w3m-view-source)
    (define-key map "=" 'w3m-view-header)
    (define-key map "s" 'w3m-history)
    (define-key map "E" 'w3m-edit-current-url)
    (define-key map "e" 'w3m-edit-this-url)
    (define-key map "C" (make-sparse-keymap))
    (define-key map "Ct" 'w3m-redisplay-with-content-type)
    (define-key map "Cc" 'w3m-redisplay-with-charset)
    (define-key map "CC" 'w3m-redisplay-and-reset)
    (define-key map "\C-c\C-b" 'report-emacs-w3m-bug)
    (define-key map "\C-c\C-c" 'w3m-submit-form)
    (define-key map "\C-c\C-k" 'w3m-process-stop)
    (setq w3m-lynx-like-map map)))

(defvar w3m-info-like-map nil
  "Info-like keymap used in emacs-w3m buffers.")
(unless w3m-info-like-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map [backspace] 'w3m-scroll-down-or-previous-url)
    (define-key map [delete] 'w3m-scroll-down-or-previous-url)
    (define-key map "\C-?" 'w3m-scroll-down-or-previous-url)
    (if (featurep 'xemacs)
	(define-key map [(shift space)] 'w3m-scroll-down-or-previous-url)
      ;; Note: It does not have an effect on Emacs 19.
      (define-key map [?\S-\ ] 'w3m-scroll-down-or-previous-url))
    (define-key map "\t" 'w3m-next-anchor)
    (define-key map [tab] 'w3m-next-anchor)
    (define-key map [(shift tab)] 'w3m-previous-anchor)
    (define-key map [(shift iso-lefttab)] 'w3m-previous-anchor)
    (define-key map "\M-\t" 'w3m-previous-anchor)
    (define-key map "\C-m" 'w3m-view-this-url)
    (define-key map [(shift return)] 'w3m-view-this-url-new-session)
    (define-key map [(shift kp-enter)] 'w3m-view-this-url-new-session)
    (if (featurep 'xemacs)
	(progn
	  (define-key map [(button2)] 'w3m-mouse-view-this-url)
	  (define-key map [(shift button2)]
	    'w3m-mouse-view-this-url-new-session))
      (define-key map [mouse-2] 'w3m-mouse-view-this-url)
      (define-key map [S-mouse-2] 'w3m-mouse-view-this-url-new-session))
    (define-key map "\C-c\C-@" 'w3m-history-store-position)
    (define-key map [?\C-c?\C- ] 'w3m-history-store-position)
    (define-key map "\C-c\C-v" 'w3m-history-restore-position)
    (define-key map " " 'w3m-scroll-up-or-next-url)
    (define-key map "a" 'w3m-bookmark-add-current-url)
    (define-key map "\M-a" 'w3m-bookmark-add-this-url)
    (define-key map "+" 'w3m-antenna-add-current-url)
    (define-key map "A" 'w3m-antenna)
    (define-key map "b" 'w3m-scroll-down-or-previous-url)
    (define-key map "c" 'w3m-print-this-url)
    (define-key map "!" 'w3m-redisplay-with-content-type)
    (define-key map "d" 'w3m-download)
    (define-key map "D" 'w3m-download-this-url)
    (define-key map "e" 'w3m-edit-current-url)
    (define-key map "E" 'w3m-edit-this-url)
    (define-key map "f" 'undefined) ;; reserved.
    (define-key map "g" 'w3m-goto-url)
    (define-key map "\M-g" 'goto-line)
    (define-key map "G" 'w3m-goto-url-new-session)
    (define-key map "h" 'describe-mode)
    (define-key map "H" 'w3m-gohome)
    (define-key map "i" (if (w3m-display-graphic-p)
			    'w3m-toggle-inline-image
			  'w3m-view-image))
    (define-key map "I" 'w3m-toggle-inline-images)
    (when (w3m-display-graphic-p)
      (define-key map "\M-[" 'w3m-zoom-out-image)
      (define-key map "\M-]" 'w3m-zoom-in-image))
    (define-key map "\M-i" 'w3m-save-image)
    (define-key map "l" 'w3m-view-previous-page)
    (define-key map "\C-l" 'recenter)
    (define-key map [(control L)] 'w3m-reload-this-page)
    (define-key map "M" 'w3m-view-url-with-external-browser)
    (define-key map "n" 'w3m-view-next-page)
    (define-key map "N" 'w3m-namazu)
    (define-key map "\M-n" 'w3m-copy-buffer)
    (define-key map "\M-k" 'w3m-cookie)
    (define-key map "\C-c\C-t" 'w3m-copy-buffer)
    (define-key map "\C-c\C-p" 'w3m-previous-buffer)
    (define-key map "\C-c\C-n" 'w3m-next-buffer)
    (define-key map "\C-c\C-w" 'w3m-delete-buffer)
    (define-key map "\C-c\M-w" 'w3m-delete-other-buffers)
    (define-key map "\C-c\C-s" 'w3m-select-buffer)
    (define-key map "\C-c\C-a" 'w3m-switch-buffer)
    (define-key map "o" 'w3m-history)
    (define-key map "O" 'w3m-db-history)
    (define-key map "p" 'w3m-view-previous-page)
    (define-key map "P" 'undecided) ;; reserved for print-this-buffer.
    (define-key map "q" 'w3m-close-window)
    (define-key map "Q" 'w3m-quit)
    (define-key map "r" 'w3m-redisplay-this-page)
    (define-key map "R" 'w3m-reload-this-page)
    (define-key map "s" 'w3m-search)
    (define-key map "S" (lambda ()
			  (interactive)
			  (let ((current-prefix-arg t))
			    (call-interactively 'w3m-search))))
    (define-key map "T" 'w3m-dtree)
    (define-key map "u" 'w3m-view-parent-page)
    (define-key map "v" 'w3m-bookmark-view)
    (define-key map "W" 'w3m-weather)
    (define-key map "y" 'w3m-print-this-url)
    (define-key map "=" 'w3m-view-header)
    (define-key map "\\" 'w3m-view-source)
    (define-key map "?" 'describe-mode)
    (define-key map ">" 'w3m-scroll-left)
    (define-key map "<" 'w3m-scroll-right)
    (define-key map [(shift right)] 'w3m-shift-left)
    (define-key map [(shift left)] 'w3m-shift-right)
    (define-key map "\M-l" 'w3m-horizontal-recenter)
    (define-key map "\C-a" 'w3m-beginning-of-line)
    (define-key map "\C-e" 'w3m-end-of-line)
    (define-key map "." 'beginning-of-buffer)
    (define-key map "^" 'w3m-view-parent-page)
    (define-key map "]" 'w3m-next-form)
    (define-key map "[" 'w3m-previous-form)
    (define-key map "}" 'w3m-next-image)
    (define-key map "{" 'w3m-previous-image)
    (define-key map "C" (make-sparse-keymap))
    (define-key map "Ct" 'w3m-redisplay-with-content-type)
    (define-key map "Cc" 'w3m-redisplay-with-charset)
    (define-key map "CC" 'w3m-redisplay-and-reset)
    (define-key map "\C-c\C-b" 'report-emacs-w3m-bug)
    (define-key map "\C-c\C-c" 'w3m-submit-form)
    (define-key map "\C-c\C-k" 'w3m-process-stop)
    (setq w3m-info-like-map map)))

(defun w3m-alive-p (&optional visible)
  "Return a buffer in which emacs-w3m is running.
If there is no emacs-w3m session, return nil.  If the optional VISIBLE
is non-nil, a visible emacs-w3m buffer is preferred.  The last visited
emacs-w3m buffer is likely to return if VISIBLE is omitted or there is
no visible buffer."
  (let* ((buffers (w3m-list-buffers t))
	 (buf (car buffers)))
    (if visible
	(progn
	  (setq visible nil)
	  (while (and (not visible)
		      buffers)
	    (when (get-buffer-window (car buffers) t)
	      (setq visible (car buffers)))
	    (setq buffers (cdr buffers)))
	  (or visible buf))
      buf)))

(defun w3m-quit (&optional force)
  "Return to a peaceful life (exiting all emacs-w3m sessions).
This command lets you quit browsing web after updating the arrived
URLs database.  Quit browsing immediately if the prefix argument FORCE
is specified, otherwise prompt you for the confirmation.  See also
`w3m-close-window'."
  (interactive "P")
  (when (or force
	    (prog1 (y-or-n-p "Do you want to exit w3m? ")
	      (w3m-message "")))
    (w3m-delete-frames-and-windows)
    (sit-for 0) ;; Delete frames seemingly fast.
    (dolist (buffer (w3m-list-buffers t))
      (w3m-cancel-refresh-timer buffer)
      (kill-buffer buffer))
    (w3m-select-buffer-close-window)
    (w3m-cache-shutdown)
    (w3m-arrived-shutdown)
    (w3m-process-shutdown)
    (when w3m-use-cookies
      (w3m-cookie-shutdown))
    (w3m-kill-all-buffer)))

(defun w3m-close-window ()
  "Return to a restless life (quitting all emacs-w3m sessions).
This command closes all emacs-w3m windows, but all the emacs-w3m
buffers remain.  Frames created for emacs-w3m sessions will also be
closed.  See also `w3m-quit'."
  (interactive)
  (let* ((buffers (w3m-list-buffers t))
	 (bufs buffers)
	 buf windows window)
    (w3m-delete-frames-and-windows)
    (while bufs
      (setq buf (pop bufs))
      (w3m-cancel-refresh-timer buf)
      (bury-buffer buf))
    (while buffers
      (setq buf (pop buffers)
	    windows (get-buffer-window-list buf 'no-minibuf t))
      (while windows
	(setq window (pop windows))
	(set-window-buffer
	 window
	 (w3m-static-cond ((featurep 'xemacs)
			   (other-buffer buf (window-frame window) nil))
			  ((>= emacs-major-version 20)
			   (other-buffer buf nil (window-frame window)))
			  (t
			   (other-buffer buf)))))))
  (w3m-select-buffer-close-window))

(unless w3m-mode-map
  (setq w3m-mode-map
	(if (eq w3m-key-binding 'info)
	    w3m-info-like-map
	  w3m-lynx-like-map)))

(defun w3m-clean-hook-options ()
  "Remove the functions which should be set newly from some hooks."
  (dolist (elem '((w3m-mode-hook w3m-setup-header-line
				 w3m-setup-widget-faces
				 w3m-update-tab-line)
		  (w3m-fontify-after-hook w3m-header-line-insert
					  w3m-update-tab-line)
		  (w3m-display-hook w3m-select-buffer-update
				    w3m-favicon-setup
				    w3m-xmas-update-tab-in-gutter)
		  (w3m-delete-buffer-hook w3m-select-buffer-update
					  w3m-update-tab-line)))
    (dolist (func (cdr elem))
      (when (memq func (symbol-value (car elem)))
	(message "Remove `%s' from `%s'" func (car elem))
	(remove-hook (car elem) func)))))

(defun w3m-mode ()
  "Major mode for browsing web.

\\<w3m-mode-map>\
\\[w3m-view-this-url]	Display the page pointed to by the link under point.
	You may use the prefix arg `2' or\
 `\\[universal-argument] \\<universal-argument-map>\
\\[universal-argument-more]\\<w3m-mode-map>' to make a new session.
\\[w3m-mouse-view-this-url]	Follow the link under the mouse pointer.
	If w3m-use-form is t, `\\[w3m-view-this-url]' and\
 `\\[w3m-mouse-view-this-url]' enable you to enter forms.
	You may use the prefix arg `2' or\
 `\\[universal-argument] \\<universal-argument-map>\
\\[universal-argument-more]\\<w3m-mode-map>' to make a new session.
\\[w3m-view-this-url-new-session]	Display the page of the link\
 in a new session.
	If the region is active, visit all the links within the region.
\\[w3m-mouse-view-this-url-new-session]	Display the page of the link\
 in a new session by mouse.

\\[w3m-submit-form]	Submit the form at point.

\\[w3m-reload-this-page]	Reload the current page.
\\[w3m-redisplay-this-page]	Redisplay the current page.
\\[w3m-redisplay-with-content-type]	Redisplay the page, specifying\
 a content type.
\\[w3m-redisplay-with-charset]	Redisplay the current page, specifying\
 a charset.
\\[w3m-redisplay-and-reset]	Redisplay the current page and reset\
 the user-specified charset and\n\tcontent type.

\\[w3m-next-anchor]	Move the point to the next anchor.
\\[w3m-previous-anchor]	Move the point to the previous anchor.
\\[w3m-next-form]	Move the point to the next form.
\\[w3m-previous-form]	Move the point to the previous form.
\\[w3m-next-image]	Move the point to the next image.
\\[w3m-previous-image]	Move the point to the previous image.

\\[w3m-view-previous-page]	Move back to the previous page in the history.
\\[w3m-view-next-page]	Move forward to the next page in the history.
\\[w3m-view-parent-page]	Attempt to move to the parent directory of\
 the page.

\\[w3m-goto-url]	Visit the web page.
\\[w3m-goto-url-new-session]	Visit the web page in a new session.
\\[w3m-gohome]	Go to the Home page.
\\[w3m-view-url-with-external-browser]	Display the current page using the\
 external browser.

\\[w3m-download-this-url]	Download the file or the page under point.

\\[w3m-view-image]	Display the image under point in the external viewer.
\\[w3m-save-image]	Save the image under point to a file.
\\[w3m-toggle-inline-images]	Toggle the visibility of all images.
\\[w3m-zoom-out-image]	Zoom in an image on the point.
\\[w3m-zoom-in-image]	Zoom out an image on the point.

\\[w3m-print-this-url]	Display the url under point and put it into\
 `kill-ring'.
\\[w3m-print-current-url]	Display the url of the current page and put\
 it into `kill-ring'.

\\[w3m-view-source]	Display the html source of the current page.
\\[w3m-view-header]	Display the header of the current page.
\\[w3m-edit-current-url]	Edit the local file displayed as the current\
 page.
\\[w3m-edit-this-url]	Edit the local file which is pointed to by URL under\
 point.

\\[w3m-scroll-up-or-next-url]	Scroll up the current window, or go to the\
 next page.
\\[w3m-scroll-down-or-previous-url]	Scroll down the current window, or\
 go to the previous page.
\\[w3m-scroll-left]	Scroll to the left.
\\[w3m-scroll-right]	Scroll to the right.
\\[w3m-shift-left]	Shift to the left.
\\[w3m-shift-right]	Shift to the right.
\\[w3m-horizontal-recenter]	Recenter horizontally.
\\[w3m-beginning-of-line]	Go to the entire beginning of line, may be\
 accompanied by scrolling.
\\[w3m-end-of-line]	Go to the entire end of line, may be accompanied\
 by scrolling.

\\[next-line]	Next line.
\\[previous-line]	Previous line.
\\[forward-char]	Forward char.
\\[backward-char]	Backward char.

\\[goto-line]	Go to the line, specifying the line number (beginning with 1).
\\[w3m-history-store-position]	Mark the current position.
\\[w3m-history-restore-position]	Go to the last marked position.

\\[w3m-history]	Display the history of pages you have visited in the\
 session.
	If it is called with the prefix arg, it displays the arrived URLs.
\\[w3m-antenna]	Display the report of changes in web pages.
	If it is called with the prefix arg, it updates the report.
\\[w3m-antenna-add-current-url]	Add the current url to the antenna database.
\\[w3m-search]	Query to the search engine a word.
	To change the server, give any prefix argument to the command.
\\[w3m-weather]	Display a weather report.
	To change the local area, give any prefix argument to the command.
\\[w3m-dtree]	Display a directory tree.
	If the prefix arg is given, display files in addition to directories.
\\[w3m-namazu]	Search files with Namazu.
	To change the index, give any prefix argument to the command.

\\[w3m-bookmark-view]	Display the bookmark.
\\[w3m-bookmark-add-current-url]	Add the url of the current page to\
 the bookmark.
	If the prefix arg is given, the user will be prompted for the url.
\\[w3m-bookmark-add-this-url]	Add the url under point to the bookmark.

\\[w3m-copy-buffer]	Create a copy of the current page as a new session.
\\[w3m-next-buffer]	Turn the page of emacs-w3m buffers ahead.
\\[w3m-previous-buffer]	Turn the page of emacs-w3m buffers behind.
\\[w3m-select-buffer]	Pop to the emacs-w3m buffers selection window up.
\\[w3m-switch-buffer]	Select one of emacs-w3m buffers at the current window.
\\[w3m-delete-buffer]	Delete the current emacs-w3m buffer.
\\[w3m-delete-other-buffers]	Delete emacs-w3m buffers except for the\
 current buffer.

\\[w3m]	Start browsing web with emacs-w3m.
\\[w3m-close-window]	Close all emacs-w3m windows, without deleteing\
 buffers.
\\[w3m-quit]	Exit browsing web.  All emacs-w3m buffers will be deleted.

\\[describe-mode]	describe-mode.

\\[report-emacs-w3m-bug]	Send a bug report to the emacs-w3m team.
"
  (kill-all-local-variables)
  (buffer-disable-undo)
  (setq major-mode 'w3m-mode)
  (setq mode-name "w3m")
  (use-local-map w3m-mode-map)
  (setq truncate-lines t
	w3m-display-inline-images w3m-default-display-inline-images)
  (when w3m-auto-show
    (when (boundp 'auto-hscroll-mode)
      (set (make-local-variable 'auto-hscroll-mode) nil))
    (when (boundp 'automatic-hscrolling)
      (set (make-local-variable 'automatic-hscrolling) nil))
    (when (boundp 'auto-show-mode)
      (set (make-local-variable 'auto-show-mode) nil))
    (when (boundp 'hscroll-mode)
      (set (make-local-variable 'hscroll-mode) nil)))
  (make-local-variable 'list-buffers-directory)
  (w3m-clean-hook-options)
  (w3m-setup-toolbar)
  (w3m-setup-menu)
  (run-hooks 'w3m-mode-setup-functions)
  (run-hooks 'w3m-mode-hook))

(defun w3m-scroll-up-or-next-url (arg)
  "Scroll the current window up ARG lines, or go to the next page."
  (interactive "P")
  (w3m-keep-region-active)
  (if (pos-visible-in-window-p (point-max))
      (if w3m-next-url
	  (w3m-goto-url w3m-next-url)
	(signal 'end-of-buffer nil))
    (scroll-up arg)))

(defun w3m-scroll-down-or-previous-url (arg)
  "Scroll the current window down ARG lines, or go to the previous page."
  (interactive "P")
  (w3m-keep-region-active)
  (if (pos-visible-in-window-p (point-min))
      (if w3m-previous-url
	  (w3m-goto-url w3m-previous-url)
	(signal 'beginning-of-buffer nil))
    (scroll-down arg)))

(defun w3m-scroll-left (arg)
  "Scroll to the left.
If ARG (the prefix) is a number, scroll the window ARG columns.
Otherwise, it defaults to `w3m-horizontal-scroll-columns'."
  (interactive "P")
  (w3m-horizontal-scroll 'left (if arg
				   (prefix-numeric-value arg)
				 w3m-horizontal-scroll-columns)))

(defun w3m-scroll-right (arg)
  "Scroll to the right.
If ARG (the prefix) is a number, scroll the window ARG columns.
Otherwise, it defaults to `w3m-horizontal-scroll-columns'."
  (interactive "P")
  (w3m-horizontal-scroll 'right (if arg
				    (prefix-numeric-value arg)
				  w3m-horizontal-scroll-columns)))

(defun w3m-shift-left (arg)
  "Shift to the left.  Shift means a fine level horizontal scrolling.
If ARG (the prefix) is a number, scroll the window ARG columns.
Otherwise, it defaults to `w3m-horizontal-shift-columns'."
  (interactive "P")
  (w3m-horizontal-scroll 'left (if arg
				   (prefix-numeric-value arg)
				 w3m-horizontal-shift-columns)))

(defun w3m-shift-right (arg)
  "Shift to the right.  Shift means a fine level horizontal scrolling.
If ARG (the prefix) is a number, scroll the window ARG columns.
Otherwise, it defaults to `w3m-horizontal-shift-columns'."
  (interactive "P")
  (w3m-horizontal-scroll 'right (if arg
				    (prefix-numeric-value arg)
				  w3m-horizontal-shift-columns)))

(defvar w3m-horizontal-scroll-done nil)
(make-variable-buffer-local 'w3m-horizontal-scroll-done)
(defvar w3m-current-position '(-1 0 0))
(make-variable-buffer-local 'w3m-current-position)

(defun w3m-auto-show ()
  "Scroll horizontally so that the point is visible."
  (when (and truncate-lines
	     w3m-auto-show
	     (not w3m-horizontal-scroll-done)
	     (not (and (eq last-command this-command)
		       (or (eq (point) (point-min))
			   (eq (point) (point-max)))))
	     (markerp (nth 1 w3m-current-position))
	     (markerp (nth 2 w3m-current-position))
	     (>= (point) (marker-position (nth 1 w3m-current-position)))
	     (<= (point) (marker-position (nth 2 w3m-current-position))))
    (w3m-horizontal-on-screen))
  (setq w3m-horizontal-scroll-done nil))

;; Ailiases to meet XEmacs bugs?
(unless (fboundp 'w3m-window-hscroll)
  (defalias 'w3m-window-hscroll 'window-hscroll))
(unless (fboundp 'w3m-current-column)
  (defalias 'w3m-current-column 'current-column))
(unless (fboundp 'w3m-set-window-hscroll)
  (defalias 'w3m-set-window-hscroll 'set-window-hscroll))

(defun w3m-horizontal-scroll (direction ncol)
  "Scroll the window NCOL columns horizontally to DIRECTION.
DIRECTON should be the symbol `left' which specifies to scroll to the
left, or any other Lisp object meaning to scroll to the right.  NCOL
should be a number.  This function is a subroutine called by the
commands `w3m-scroll-left', `w3m-scroll-right', `w3m-shift-left' and
`w3m-shift-right'."
  (setq w3m-horizontal-scroll-done t)
  (let ((inhibit-point-motion-hooks t))
    (w3m-set-window-hscroll (selected-window)
			    (max 0
				 (+ (w3m-window-hscroll)
				    (if (eq direction 'left) ncol (- ncol)))))
    (let ((hs (w3m-window-hscroll)))
      (unless (and (>= (- (current-column) hs) 0)
		   (< (- (current-column) hs) (window-width)))
	(move-to-column (if (eq direction 'left) hs
			  (+ hs (window-width)
			     (w3m-static-if (featurep 'xemacs) -3 -2))))))))

(defun w3m-horizontal-on-screen ()
  "Scroll the window horizontally so that the current position is visible.
See the documentation for the `w3m-horizontal-scroll-division' variable
for details."
  (when w3m-auto-show
    (setq w3m-horizontal-scroll-done t)
    (let ((cc (w3m-current-column))
	  (hs (w3m-window-hscroll))
	  (ww (window-width))
	  (inhibit-point-motion-hooks t))
      (unless (and (>= (- cc hs) 0)
		   (< (+ (- cc hs) (if (eolp)
				       0
				     (w3m-static-if (featurep 'xemacs)
					 3 2)))	;; '$$'
		      ww))
	(w3m-set-window-hscroll
	 (selected-window)
	 (max 0 (- cc (if (> hs cc)
			  (/ ww w3m-horizontal-scroll-division)
			(* (/ ww w3m-horizontal-scroll-division)
			   (1- w3m-horizontal-scroll-division))))))))))

(defun w3m-horizontal-recenter (&optional arg)
  "Recenter horizontally.  With ARG, put the point on the column ARG.
If `truncate-lines' is nil, it does nothing besides resetting the
window's hscroll."
  (interactive "P")
  (if truncate-lines
      (progn
	(cond ((< (w3m-current-column) (window-hscroll))
	       (move-to-column (w3m-window-hscroll))
	       (setq arg 0))
	      ((>= (w3m-current-column) (+ (window-hscroll) (window-width)))
	       (move-to-column (+ (w3m-window-hscroll) (window-width) -2))
	       (setq arg -1))
	      ((listp arg)
	       (setq arg (car arg))))
	(w3m-set-window-hscroll
	 (selected-window)
	 (if (numberp arg)
	     (if (>= arg 0)
		 (max (- (current-column) arg) 0)
	       (let* ((home (point))
		      (inhibit-point-motion-hooks t)
		      (maxcolumn (prog2
				     (end-of-line)
				     (1- (current-column))
				   (goto-char home))))
		 (max (min (- (current-column)
			      (window-width)
			      arg
			      -2)
			   maxcolumn)
		      0)))
	   (max (- (current-column) (/ (window-width) 2) -1)
		0))))
    (set-window-hscroll (selected-window) 0)))

(defun w3m-beginning-of-line (&optional arg)
  "Make the beginning of the line visible and move the point to there."
  (interactive "P")
  (w3m-keep-region-active)
  (when (listp arg)
    (setq arg (car arg)))
  (set-window-hscroll (selected-window) 0)
  (beginning-of-line arg))

(defun w3m-end-of-line (&optional arg)
  "Move the point to the end of the line and scroll the window left.
It makes the ends of upper and lower three lines visible.  If
`truncate-lines' is nil, it works identically as `end-of-line'."
  (interactive "P")
  (w3m-keep-region-active)
  (if truncate-lines
      (progn
	(when (listp arg)
	  (setq arg (car arg)))
	(forward-line (1- (or arg 1)))
	(let ((inhibit-point-motion-hooks t)
	      home)
	  (end-of-line)
	  (setq home (point)
		arg (current-column))
	  (dolist (n '(-3 -2 -1 1 2 3))
	    (forward-line n)
	    (end-of-line)
	    (setq arg (max (current-column) arg))
	    (goto-char home)))
	(setq temporary-goal-column arg
	      this-command 'next-line)
	(w3m-set-window-hscroll (selected-window)
				(max (- arg (window-width) -2) 0)))
    (set-window-hscroll (selected-window) 0)
    (end-of-line arg)))

(defun w3m-pattern-uri-replace (uri format)
  "Create a new uri from URI matched by last search according to FORMAT."
  (replace-match format nil nil uri))

(defun w3m-uri-replace (uri)
  "Return the converted URI according to `w3m-uri-replace-alist'."
  (catch 'found-replacement
    (dolist (elem w3m-uri-replace-alist uri)
      (when (string-match (car elem) uri)
	(if (setq uri
		  (cond
		   ((consp (cdr elem))
		    (apply (cadr elem) uri (cddr elem)))
		   ;; Rest conditions are inserted in order to keep
		   ;; backward compatibility.
		   ((functionp (cdr elem))
		    (funcall (cdr elem) uri))
		   ((stringp (cdr elem))
		    (w3m-pattern-uri-replace uri (cdr elem)))))
	    (throw 'found-replacement uri)
	  (error "Invalid replacement: %s" elem))))))

(defun w3m-goto-mailto-url (url &optional post-data)
  (let ((before (nreverse (buffer-list)))
	comp info buffers buffer function)
    (save-window-excursion
      (if (and (symbolp w3m-mailto-url-function)
	       (fboundp w3m-mailto-url-function))
	  (funcall w3m-mailto-url-function url)
	;; Require `mail-user-agent' setting
	(unless (and (boundp 'mail-user-agent)
		     (symbol-value 'mail-user-agent))
	  (error "You must specify the valid value to `mail-user-agent'"))
	(unless (and (setq comp (get (symbol-value 'mail-user-agent)
				     'composefunc))
		     (fboundp comp))
	  (error "No function to compose a mail in `%s'"
		 (symbol-value 'mail-user-agent)))
	;; Use rfc2368.el if exist.
	;; rfc2368.el is written by Sen Nagata.
	;; You can find it in "contrib" directory of Mew package
	;; or in "utils" directory of Wanderlust package.
	(if (or (featurep 'rfc2368)
		(condition-case nil (require 'rfc2368) (error nil)))
	    (progn
	      (setq info (rfc2368-parse-mailto-url url))
	      (apply comp
		     (append (mapcar (lambda (x)
				       (cdr (assoc x info)))
				     '("To" "Subject"))
			     (if post-data
				 (list
				  (list (cons
					 "body"
					 (or (and
					      (consp post-data)
					      (concat (car post-data) "\n"))
					     (concat post-data "\n")))))))))
	  ;; without rfc2368.el.
	  (funcall comp (match-string 1 url)))))
    (setq buffers (nreverse (buffer-list)))
    (save-current-buffer
      (while buffers
	(setq buffer (car buffers)
	      buffers (cdr buffers))
	(unless (memq buffer before)
	  (set-buffer buffer)
	  (when (setq function
		      (cdr (assq major-mode
				 w3m-mailto-url-popup-function-alist)))
	    (setq buffers nil)))))
    (when function
      (let (special-display-buffer-names
	    special-display-regexps
	    same-window-buffer-names
	    same-window-regexps)
	(funcall function buffer)))))

(defun w3m-convert-ftp-url-for-emacsen (url)
  (or (and (string-match "^ftp://?\\([^/@]+@\\)?\\([^/]+\\)\\(/~/\\)?" url)
	   (concat "/"
		   (if (match-beginning 1)
		       (substring url (match-beginning 1) (match-end 1))
		     "anonymous@")
		   (substring url (match-beginning 2) (match-end 2))
		   ":"
		   (substring url (match-end 2))))
      (error "URL is strange")))

(defun w3m-file-directory-p (file)
  "Emulate the `file-directory-p' function for the remote file FILE."
  (when (file-exists-p file)
    (let (dirp (i 10))
      (catch 'loop
	(while (> i 0)
	  (setq dirp (car (file-attributes file)))
	  (if (stringp dirp)
	      (setq file (expand-file-name
			  dirp
			  (file-name-directory (directory-file-name file)))
		    i (1- i))
	    (throw 'loop dirp)))))))

(defun w3m-goto-ftp-url (url &optional filename)
  "Copy a remote file to the local system or run dired for ftp URLs.
If URL looks like a file, it will perform the copy.  Otherwise, it
will run `dired-other-window' using `ange-ftp' or `efs'.  Optional
FILENAME specifies the name of a local file.  If FILENAME is omitted,
this function will prompt user for it."
  (let ((ftp (w3m-convert-ftp-url-for-emacsen url))
	file)
    (if (or (string-equal "/" (substring ftp -1))
	    ;; `file-directory-p' takes a long time for remote files.
	    ;; `file-directory-p' returns t in Emacsen, anytime.
	    (w3m-file-directory-p ftp))
	(dired-other-window ftp)
      (setq file (file-name-nondirectory ftp))
      (unless filename
	(setq filename (w3m-read-file-name nil nil file)))
      (unless (file-writable-p (file-name-directory filename))
	(error "Permission denied, %s" (file-name-directory filename)))
      (when (or (not (file-exists-p filename))
		(if (file-writable-p filename)
		    (and (prog1
			     (y-or-n-p
			      (format "File(%s) already exists. Overwrite? "
				      filename))
			   (w3m-message ""))
			 (progn
			   (delete-file filename)
			   t))
		  (error "Permission denied, %s" filename)))
	(copy-file ftp filename)
	(message "Wrote %s" filename)))))

(eval-and-compile
  (unless (fboundp 'w3m-add-local-hook)
    (defun w3m-add-local-hook (hook function &optional append)
      "Add to the buffer-local value of HOOK the function FUNCTION.
Note: this function is designed for Emacsen other than Emacs 21."
      (make-local-hook hook)
      (add-hook hook function append t))))

(defun w3m-store-current-position ()
  "Memorize the current positions whenever every command starts.
The value will be held in the `w3m-current-position' variable.  This
function is designed as the hook function which is registered to
`pre-command-hook' by `w3m-buffer-setup'."
  (setq w3m-current-position (list (point)
				   (copy-marker (line-beginning-position))
				   (copy-marker (line-end-position)))))

(defun w3m-check-current-position ()
  "Run `w3m-after-cursor-move-hook' if the point gets away from the window.
This function is designed as the hook function which is registered to
`post-command-hook' by `w3m-buffer-setup'."
  (when (/= (point) (car w3m-current-position))
    (run-hooks 'w3m-after-cursor-move-hook)))

(defun w3m-buffer-setup ()
  "Generate a new buffer, select it and set it up for emacs-w3m.
When the current buffer has already been prepared, it won't bother to
generate a new buffer."
  (unless (eq major-mode 'w3m-mode)
    (let ((buffer (w3m-alive-p t)))
      (if buffer
	  (set-buffer buffer)
	(set-buffer (generate-new-buffer "*w3m*"))
	(w3m-mode))))
  ;; It may have been set to nil for viewing a page source or a header.
  (setq truncate-lines t)
  (w3m-add-local-hook 'pre-command-hook 'w3m-store-current-position)
  (w3m-add-local-hook 'post-command-hook 'w3m-check-current-position)
  (w3m-static-when (or (featurep 'xemacs)
		       (> emacs-major-version 20))
    (w3m-initialize-graphic-icons))
  (setq mode-line-buffer-identification
	'("%b "
	  (w3m-current-process
	   w3m-modeline-process-status-on
	   (w3m-current-ssl
	    (w3m-display-inline-images
	     w3m-modeline-ssl-image-status-on
	     w3m-modeline-ssl-status-off)
	    (w3m-display-inline-images
	     w3m-modeline-image-status-on
	     w3m-modeline-status-off)))
	  (w3m-show-graphic-icons-in-mode-line
	   (w3m-use-favicon
	    (w3m-favicon-image
	     w3m-modeline-favicon
	     w3m-modeline-separator)
	    w3m-modeline-separator)
	   w3m-modeline-separator)
	  w3m-current-title))
  (unless (assq 'w3m-current-process mode-line-process)
    (setq mode-line-process
	  (cons (list 'w3m-current-process 'w3m-process-modeline-string)
		mode-line-process))))

;;;###autoload
(defun w3m-goto-url (url &optional reload charset post-data referer handler
			 element)
  "Visit World Wide Web pages.  This is the primitive function of `w3m'.
If the second argument RELOAD is non-nil, reload a content of URL.
Except that if it is 'redisplay, re-display the page without reloading.
The third argument CHARSET specifies a charset to be used for decoding
a content.
The fourth argument POST-DATA should be a string or a cons cell.  If
it is a string, it makes this function request a body as if the
content-type is \"x-www-form-urlencoded\".  If it is a cons cell, the
car of a cell is used as the content-type and the cdr of a cell is
used as the body.
If the fifth argument REFERER is specified, it is used for a Referer:
field for this request.
The remaining HANDLER and ELEMENT[1] are for the internal operations
of emacs-w3m.
You can also use \"quicksearch\" url schemes such as \"gg:emacs\" which
would search for the term \"emacs\" with the Google search engine.  See
the `w3m-search' function and the variable `w3m-uri-replace-alist'.

\[1] A note for the developers: ELEMENT is a history element which has
already been registered in the `w3m-history-flat' variable.  It is
corresponding to URL to be retrieved at this time, not for the url of
the current page."
  (interactive
   (list
    (w3m-input-url nil
		   (or (w3m-active-region-or-url-at-point)
		       (when (stringp w3m-current-url)
			 (if (string-match "\\`about://\\(header\\|source\\)/"
					   w3m-current-url)
			     (substring w3m-current-url (match-end 0))
			   w3m-current-url))))
    current-prefix-arg
    (w3m-static-if (fboundp 'universal-coding-system-argument)
	coding-system-for-read)))
  (set-text-properties 0 (length url) nil url)
  (setq url (w3m-uri-replace url))
  (unless (or (w3m-url-local-p url)
	      (string-match "\\`about:" url))
    (setq url (w3m-url-transfer-encode-string url w3m-default-coding-system)))
  (cond
   ;; process mailto: protocol
   ((string-match "\\`mailto:" url)
    (w3m-goto-mailto-url url post-data))
   ;; process ftp: protocol
   ((and w3m-use-ange-ftp
	 (string-match "\\`ftps?://" url)
	 (not (string= "text/html" (w3m-local-content-type url))))
    (w3m-goto-ftp-url url))
   ;; find-file directly
   ((condition-case nil
	(and (w3m-url-local-p url)
	     w3m-local-find-file-function
	     (let ((base-url (w3m-url-strip-fragment url))
		   (match (car w3m-local-find-file-regexps))
		   nomatch file)
	       (and (or (not match)
			(string-match match base-url))
		    (not (and (setq nomatch (cdr w3m-local-find-file-regexps))
			      (string-match nomatch base-url)))
		    (setq file (w3m-url-to-file-name base-url))
		    (file-exists-p file)
		    (not (file-directory-p file))
		    (prog1
			t
		      (funcall (if (functionp w3m-local-find-file-function)
				   w3m-local-find-file-function
				 (eval w3m-local-find-file-function))
			       file)))))
      (error nil)))
   ((w3m-url-valid url)
    (w3m-buffer-setup)			; Setup buffer.
    (w3m-arrived-setup)			; Setup arrived database.
    (w3m-popup-buffer (current-buffer))
    (w3m-cancel-refresh-timer (current-buffer))
    (when w3m-current-process
      (error "%s"
	     (substitute-command-keys "
Cannot run two w3m processes simultaneously \
\(Type `\\<w3m-mode-map>\\[w3m-process-stop]' to stop asynchronous process)")))
    (w3m-process-stop (current-buffer))	; Stop all processes retrieving images.
    ;; Store the current position in the history structure.
    (w3m-history-store-position)
    ;; Access url group
    (if (string-match "\\`group:" url)
	(let ((urls (mapcar 'w3m-url-decode-string
			    (split-string (substring url (match-end 0)) "&"))))
	  (w3m-process-do
	      (type (prog1
			(w3m-goto-url (car urls))
		      (dolist (url (cdr urls))
			(save-excursion
			  (set-buffer (w3m-copy-buffer nil nil nil 'empty))
			  (save-window-excursion
			    (w3m-goto-url url))))))
	    type))
      ;; Retrieve the page.
      (lexical-let ((orig url)
		    (url (w3m-url-strip-authinfo url))
		    (reload (and (not (eq reload 'redisplay)) reload))
		    (redisplay (eq reload 'redisplay))
		    (charset charset)
		    (post-data post-data)
		    (referer referer)
		    (name)
		    (history-position (get-text-property (point)
							 'history-position))
		    (reuse-history w3m-history-reuse-history-elements))
	(when w3m-current-forms
	  ;; Store the current forms in the history structure.
	  (w3m-history-plist-put :forms w3m-current-forms))
	(let ((w3m-current-buffer (current-buffer)))
	  (unless element
	    (setq element
		  (if (and (equal referer "about://history/")
			   history-position)
		      (w3m-history-element history-position t)
		    (if w3m-history-reuse-history-elements
			(w3m-history-assoc url)))))
	  ;; Set current forms using the history structure.
	  (when (setq w3m-current-forms
		      (when (and (not reload) ; If reloading, ignore history.
				 (null post-data) ; If post, ignore history.
				 (w3m-cache-available-p url))
			;; Don't use `w3m-history-plist-get' here.
			(plist-get (nthcdr 3 element) :forms)))
	    ;; Mark that the form is from history structure.
	    (setq w3m-current-forms (cons t w3m-current-forms)))
	  (when (and post-data element)
	    ;; Remove processing url's forms from the history structure.
	    (w3m-history-set-plist (cadr element) :forms nil))
	  ;; local directory URL check
	  (when (and (w3m-url-local-p url)
		     (file-directory-p (w3m-url-to-file-name url))
		     (setq url (file-name-as-directory url))
		     (eq w3m-local-directory-view-method 'w3m-dtree)
		     (string-match "\\`file:///" url))
	    (setq url (replace-match "about://dtree/" nil nil url)
		  orig url))
	  ;; Split body and fragments.
	  (and (string-match w3m-url-components-regexp url)
	       (match-beginning 8)
	       (setq name (match-string 9 url)
		     url (substring url 0 (match-beginning 8))))
	  (w3m-process-do
	      (action
	       (if (and (not reload)
			(not redisplay)
			(stringp w3m-current-url)
			(string= url w3m-current-url))
		   (progn
		     (w3m-refontify-anchor)
		     'cursor-moved)
		 (setq w3m-current-process
		       (w3m-retrieve-and-render orig reload charset
						post-data referer handler))))
	    (with-current-buffer w3m-current-buffer
	      (setq w3m-current-process nil)
	      (if (not action)
		  (progn
		    (w3m-history-push w3m-current-url
				      (list :title (or w3m-current-title
						       "<no-title>")))
		    (goto-char (point-min)))
		(if (and name (w3m-search-name-anchor name))
		    (setf (w3m-arrived-time (w3m-url-strip-authinfo orig))
			  (w3m-arrived-time url))
		  (goto-char (point-min)))
		(unless (eq action 'cursor-moved)
		  (if (equal referer "about://history/")
		      ;; Don't sprout a new branch for the existing history
		      ;; element.
		      (let ((w3m-history-reuse-history-elements t))
			(w3m-history-push w3m-current-url
					  (list :title w3m-current-title))
			;; Fix the history position pointers.
			(when history-position
			  (setcar w3m-history
				  (w3m-history-regenerate-pointers
				   history-position))))
		    (let ((w3m-history-reuse-history-elements reuse-history)
			  (position (when (eq 'reload reuse-history)
				      (cadar w3m-history))))
		      (w3m-history-push w3m-current-url
					(list :title w3m-current-title))
		      (when position
			(w3m-history-set-current position))))
		  (w3m-history-add-properties (list :referer referer
						    :post-data post-data))
		  (unless w3m-toggle-inline-images-permanently
		    (setq w3m-display-inline-images
			  w3m-default-display-inline-images))
		  (cond ((w3m-display-inline-images-p)
			 (and w3m-force-redisplay (sit-for 0))
			 (w3m-toggle-inline-images 'force reload))
			((and (w3m-display-graphic-p)
			      (eq action 'image-page))
			 (and w3m-force-redisplay (sit-for 0))
			 (w3m-toggle-inline-image 'force reload)))))
	      (setq buffer-read-only t)
	      (set-buffer-modified-p nil)
	      (setq list-buffers-directory w3m-current-title)
	      ;; must be `w3m-current-url'
	      (setq default-directory (w3m-current-directory w3m-current-url))
	      (w3m-update-toolbar)
	      (w3m-select-buffer-update)
	      (let ((real-url (or (w3m-real-url url) url)))
		(run-hook-with-args 'w3m-display-functions real-url)
		(run-hook-with-args 'w3m-display-hook real-url))
	      ;; restore position must call after hooks for localcgi.
	      (when (or reload redisplay)
		(w3m-history-restore-position))
	      (w3m-refresh-at-time)))))))
   (t (w3m-message "Invalid URL: %s" url))))

(defun w3m-current-directory (url)
  (let (file)
    (file-name-as-directory
     (if (and url (stringp url))
	 (if (string-match "\\`ftp://" url)
	     (progn
	       (setq file (w3m-convert-ftp-url-for-emacsen url))
	       (if (string-match "/\\`" file)
		   file
		 (file-name-directory file)))
	   (setq file (w3m-url-to-file-name url))
	   (if (and file (file-exists-p file))
	       (if (file-directory-p file)
		   file
		 (file-name-directory file))
	     w3m-profile-directory))
       w3m-profile-directory))))

;; Alias to meet `run-at-time' bug of XEmacs.  It runs the timer
;; function almost immediately, so we use the emulated version
;; instead.
(unless (fboundp 'w3m-run-at-time)
  (defalias 'w3m-run-at-time 'run-at-time))

(defun w3m-refresh-at-time ()
  (when (and w3m-use-refresh w3m-current-refresh)
    (if (= (car w3m-current-refresh) 0)
	(w3m-goto-url-with-timer (cdr w3m-current-refresh) (current-buffer))
      (setq w3m-refresh-timer
	    (w3m-run-at-time (car w3m-current-refresh)
			     nil
			     'w3m-goto-url-with-timer
			     (cdr w3m-current-refresh)
			     (current-buffer))))))

(defun w3m-goto-url-with-timer (url buffer)
  "Run the `w3m-goto-url' function by the refresh timer."
  (when (and (w3m-url-valid url) buffer (get-buffer buffer))
    (if (get-buffer-window buffer)
	(save-selected-window
	  (pop-to-buffer buffer)
	  (with-current-buffer buffer
	    (w3m-cancel-refresh-timer buffer)
	    (w3m-goto-url url)))
      (with-current-buffer buffer
	(w3m-cancel-refresh-timer buffer)))))

;;;###autoload
(defun w3m-goto-url-new-session (url &optional reload charset post-data
				     referer)
  "Visit World Wide Web pages in a new session.
If you invoke this command in the emacs-w3m buffer, the new session
will be created by copying the current session.  Otherwise, the new
session will start afresh."
  (interactive
   (list
    (w3m-input-url nil
		   (when (stringp w3m-current-url)
		     (if (string-match "\\`about://\\(header\\|source\\)/"
				       w3m-current-url)
			 (substring w3m-current-url (match-end 0))
		       w3m-current-url)))
    current-prefix-arg
    (w3m-static-if (fboundp 'universal-coding-system-argument)
	coding-system-for-read)
    nil ;; post-data
    nil)) ;; referer
  (let (buffer)
    (if (or (eq 'w3m-mode major-mode)
	    (and (setq buffer (w3m-alive-p))
		 (progn
		   (w3m-popup-buffer buffer)
		   t)))
	(progn
	  (switch-to-buffer (setq buffer
				  (w3m-copy-buffer nil nil nil 'empty)))
	  (w3m-display-progress-message url)
	  ;; When new URL has `name' portion, we have to goto the base url
	  ;; because generated buffer has no content at this moment.
	  (when (and (string-match w3m-url-components-regexp url)
		     (match-beginning 8))
	    (w3m-goto-url (substring url 0 (match-beginning 8))
			  reload charset post-data referer))
	  (w3m-goto-url url reload charset post-data referer)
	  ;; Delete useless newly created buffer if it is empty.
	  (w3m-delete-buffer-if-empty buffer))
      (w3m-goto-url url))))

(defun w3m-move-point-for-localcgi (url)
  (when (and (w3m-url-local-p url)
	     (file-directory-p (w3m-url-to-file-name url))
	     (not (eq w3m-local-directory-view-method 'w3m-dtree))
	     (= (point-min) (point))
	     (w3m-search-name-anchor "current" 'quiet))
    (recenter (/ (window-height) 5))))

;;;###autoload
(defun w3m-gohome ()
  "Go to the Home page."
  (interactive)
  (unless w3m-home-page
    (error "You have to specify the value of `w3m-home-page'"))
  (w3m-goto-url w3m-home-page))

(defun w3m-reload-this-page (&optional arg)
  "Reload the current page, disregarding the cached contents.
If the prefix arg ARG is given, it also clears forms and post data."
  (interactive "P")
  (if w3m-current-url
      (let ((w3m-history-reuse-history-elements
	     ;; Don't move the history position.
	     'reload)
	    post-data)
	(if arg
	    (progn
	      (w3m-history-remove-properties '(:forms nil :post-data nil))
	      (setq w3m-current-forms nil))
	  (when (and (setq post-data (w3m-history-plist-get :post-data))
		     (not (y-or-n-p "Repost form data? ")))
	    (setq post-data nil)))
	(w3m-goto-url w3m-current-url 'reload nil post-data
		      (w3m-history-plist-get :referer)
		      nil
		      (w3m-history-element (cadar w3m-history) t)))
    (w3m-message "Can't reload this page")))

(defun w3m-redisplay-this-page (&optional arg)
  "Redisplay the current page.
If the prefix arg ARG is given, it toggles the visibility of images."
  (interactive "P")
  (if (null w3m-current-url)
      (w3m-message "Can't redisplay this page")
    (when arg
      (setq w3m-display-inline-images (not w3m-display-inline-images)))
    (w3m-goto-url w3m-current-url 'redisplay)))

(defun w3m-redisplay-and-reset (&optional arg)
  "Redisplay the current page and reset the user-specified values.
This function clears the charset and the content type which the user
specified for overriding the values of what the page requires.  The
prefix argument ARG is passed to the `w3m-redisplay-this-page'
function (which see)."
  (interactive "P")
  (if (null w3m-current-url)
      (w3m-message "Can't execute this page")
    (setf (w3m-arrived-content-type w3m-current-url) nil)
    (setf (w3m-arrived-content-charset w3m-current-url) nil)
    (w3m-redisplay-this-page arg)))

(defun w3m-redisplay-with-charset (&optional arg)
  "Redisplay the current page, specifying a charset.
If the user enters the empty string, the value which once was used for
decoding the page is used.  The prefix argument ARG is passed to the
`w3m-redisplay-this-page' function (which see)."
  (interactive "P")
  (if (null w3m-current-url)
      (w3m-message "Can't execute the command")
    (setf (w3m-arrived-content-charset w3m-current-url)
	  (w3m-read-content-charset
	   (format "Content-charset (current %s, default reset): "
		   w3m-current-coding-system)))
    (w3m-redisplay-this-page arg)))

(defun w3m-redisplay-with-content-type (&optional arg)
  "Redisplay the current page, specifying a content type.
If the user enters the empty string, it uses the value which was
specified by the page's contents itself.  The prefix argument ARG is
passed to the `w3m-redisplay-this-page' function (which see)."
  (interactive "P")
  (if (null w3m-current-url)
      (w3m-message "Can't execute this page")
    (setf (w3m-arrived-content-type w3m-current-url)
	  (let ((type (completing-read
		       (format "Content-type (current %s, default reset): "
			       (or (w3m-arrived-content-type w3m-current-url)
				   (w3m-content-type w3m-current-url)))
		       w3m-content-type-alist nil t)))
	    (unless (string= type "") type)))
    (w3m-redisplay-this-page arg)))

(defun w3m-examine-command-line-args ()
  "Return a url when the `w3m' command is invoked from the command line.
The `w3m' Lisp command can be invoked even in the batch mode, e.g.,
``emacs -f w3m'' or ``emacs -f w3m url''.  This function is used in
the very case, it extracts a url string from the command line
arguments and passes it to the `w3m' command.  If a url is omitted, it
defaults to the value of `w3m-home-page' or \"about:\"."
  (let ((url (car command-line-args-left))
	(directives '("-f" "-funcall" "--funcall" "-e"))
	args directive num)
    (if (and url
	     (not (string-match "\\`-" url)))
	(when (and
	       (setq args (w3m-static-if (featurep 'xemacs)
			      ;; Elements of `command-line-args' and
			      ;; `command-line-args-left' aren't the
			      ;; identical objects under XEmacs.
			      (member url command-line-args)
			    (memq url command-line-args)))
	       (>= (setq num (- (length command-line-args) (length args) 1))
		   2)
	       (equal (nth num command-line-args) "w3m")
	       (member (setq directive (nth (1- num) command-line-args))
		       directives))
	  (setq command-line-args-left (cdr command-line-args-left))
	  (setcdr (nthcdr (- num 2) command-line-args)
		  (cons (concat directive " w3m " url)
			(nthcdr (+ num 2) command-line-args)))
	  url)
      (when (and
	     (setq args (member "w3m" command-line-args))
	     (member
	      (setq directive
		    (nth (setq num
			       (- (length command-line-args) (length args) 1))
			 command-line-args))
	      directives))
	(setcdr (nthcdr (1- num) command-line-args)
		(cons (concat directive " w3m")
		      (nthcdr (+ num 2) command-line-args)))
	(or w3m-home-page "about:")))))

;;;###autoload
(defun w3m (&optional url new-session interactive-p)
  "Visit World Wide Web pages using the external w3m command.

When you invoke this command interactively for the first time, it will
visit a page which is pointed to by a string like url around the
cursor position or the home page specified by the `w3m-home-page'
variable, but you will be prompted for a URL if `w3m-quick-start' is
nil (default t) or `w3m-home-page' is nil.

The variables `w3m-pop-up-windows' and `w3m-pop-up-frames' control
whether this command should pop to a window or a frame up for the
session.

When emacs-w3m sessions have already been opened, this command will
pop to the existing window or frame up, but if `w3m-quick-start' is
nil, \(default t), you will be prompted for a URL (which defaults to
`popup' meaning to pop to an existing emacs-w3m buffer up).

In addition, if the prefix argument is given or you enter the empty
string for the prompt, it will visit the home page specified by the
`w3m-home-page' variable or the \"about:\" page.

You can also run this command in the batch mode as follows:

  emacs -f w3m http://emacs-w3m.namazu.org/ &

In that case, or if this command is called non-interactively, the
variables `w3m-pop-up-windows' and `w3m-pop-up-frames' will be ignored
\(treated as nil) and it will run emacs-w3m at the current (or the
initial) window.

If the optional NEW-SESSION is non-nil, this function makes a new
emacs-w3m buffer.  Besides that, it also makes a new emacs-w3m buffer
if `w3m-make-new-session' is non-nil and a user specifies a url string.

The optional INTERACTIVE-P is for the internal use; it is mainly used
to check whether Emacs 21.4 calls this function as an interactive
command in the batch mode."
  (interactive
   (let ((url
	  ;; Emacs 21.4 calls a Lisp command interactively even if it
	  ;; is in the batch mode.  If the following function returns
	  ;; non-nil value, it means this function is called in the
	  ;; batch mode, and we don't treat it as what it is called to
	  ;; interactively.
	  (w3m-examine-command-line-args))
	 new)
     (list
      ;; url
      (or url
	  (let ((default (if (w3m-alive-p) 'popup w3m-home-page)))
	    (setq new (if current-prefix-arg
			  default
			(w3m-input-url nil nil default w3m-quick-start)))))
      ;; new-session
      (and w3m-make-new-session
	   (w3m-alive-p)
	   (not (eq new 'popup)))
      ;; interactive-p
      (not url))))
  (let ((nofetch (eq url 'popup))
	(buffer (unless new-session (w3m-alive-p t)))
	(popup-frame-p (and (not interactive-p) (w3m-popup-frame-p)))
	(w3m-pop-up-frames (and interactive-p w3m-pop-up-frames))
	(w3m-pop-up-windows (and interactive-p w3m-pop-up-windows)))
    (unless (and (stringp url)
		 (> (length url) 0))
      (if buffer
	  (setq nofetch t)
	;; This command was possibly be called non-interactively or as
	;; the batch mode.
	(setq url (or (w3m-examine-command-line-args)
		      ;; Unlikely but this function was called with no url.
		      "about:")
	      nofetch nil)))
    (unless buffer
      ;; It means `new-session' is non-nil or there's no emacs-w3m buffer.
      ;; At any rate, we create a new emacs-w3m buffer in this case.
      (with-current-buffer (setq buffer (generate-new-buffer "*w3m*"))
	(w3m-mode)))
    (w3m-popup-buffer buffer)
    (unless nofetch
      ;; `unwind-protect' is needed since a process may be terminated by C-g.
      (unwind-protect
	  (w3m-goto-url url)
	;; Delete useless newly created buffer if it is empty.
	(w3m-delete-buffer-if-empty buffer)))))

(eval-when-compile
  (autoload 'browse-url-interactive-arg "browse-url"))

;;;###autoload
(defun w3m-browse-url (url &optional new-session)
  "Ask emacs-w3m to browse URL.
NEW-SESSION specifies whether to create a new emacs-w3m session.  URL
defaults to the string looking like a url around the cursor position.
Pop to a window or a frame up according to `w3m-pop-up-windows' and
`w3m-pop-up-frames'."
  (interactive (progn
		 (require 'browse-url)
		 (browse-url-interactive-arg "Emacs-w3m URL: ")))
  (when (stringp url)
    (setq url (w3m-canonicalize-url url))
    (if new-session
	(w3m-goto-url-new-session url)
      (w3m-goto-url url))))

;;;###autoload
(defun w3m-find-file (file)
  "Function used to open FILE whose name is expressed in ordinary format.
The file name will be converted into the file: scheme."
  (interactive "fFilename: ")
  (w3m-goto-url (w3m-expand-file-name-as-url file)
		nil
		(w3m-static-if (fboundp 'universal-coding-system-argument)
		    coding-system-for-read)))

(defun w3m-cygwin-path (path)
  "Convert PATH in the win32 style into the cygwin format.
ex. c:/dir/file => //c/dir/file"
  (if (string-match "^\\([A-Za-z]\\):" path)
      (replace-match "//\\1" nil nil path)
    path))

;;;###autoload
(defun w3m-region (start end &optional url charset)
  "Render the region of the current buffer between START and END.
URL specifies the address where the contents come from.  It can be
omitted or nil when the address is not identified.  CHARSET is used
for decoding the contents.  If it is nil, this function attempts to
parse the meta tag to extract the charset."
  (interactive
   (list (region-beginning)
	 (region-end)
	 (w3m-expand-file-name-as-url
	  (or (buffer-file-name) default-directory))))
  (save-restriction
    (w3m-process-stop (current-buffer))
    (narrow-to-region start end)
    (w3m-clear-local-variables)
    (let ((w3m-current-buffer (current-buffer)))
      (unless charset
	(setq charset (w3m-correct-charset (w3m-detect-meta-charset))))
      (setq w3m-current-url url
	    w3m-current-base-url url
	    w3m-current-coding-system
	    (if charset
		(w3m-charset-to-coding-system charset)
	      w3m-coding-system)
	    w3m-current-title
	    (let (w3m-use-refresh)
	      (w3m-rendering-buffer charset)))
      (w3m-fontify)
      (when (w3m-display-inline-images-p)
	(and w3m-force-redisplay (sit-for 0))
	(w3m-toggle-inline-images 'force)))))


;;; About:
(defun w3m-about (url &rest args)
  (insert "<!doctype html public \"-//W3C//DTD HTML 3.2//EN\">
<html>
<head><title>About emacs-w3m</title></head>
<body>
<center>
Welcome to <a href=\"http://emacs-w3m.namazu.org/\">\
<img src=\"about://emacs-w3m.gif\" alt=\"emacs-w3m\" width=\"83\"
height=\"14\"></a>!<br><br>
emacs-w3m is an interface program of
<a href=\"http://w3m.sourceforge.net/\">w3m</a>,
works on Emacs.
</center>
</body>
</html>")
  "text/html")

(defun w3m-view-source ()
  "Display the html source of the current buffer."
  (interactive)
  (if w3m-current-url
      (let ((w3m-prefer-cache t))
	(cond
	 ((string-match "\\`about://source/" w3m-current-url)
	  (w3m-goto-url (substring w3m-current-url (match-end 0))))
	 ((string-match "\\`about://header/" w3m-current-url)
	  (w3m-goto-url (concat "about://source/"
				(substring w3m-current-url (match-end 0))))
	  (setq truncate-lines nil))
	 (t
	  (w3m-goto-url  (concat "about://source/" w3m-current-url))
	  (setq truncate-lines nil))))
    (w3m-message "Can't view page source")))

(defun w3m-make-separator ()
  (if (string= w3m-language "Japanese")
      (w3m-static-if (boundp 'MULE)
	  ;; `make-string' doesn't support Japanese chars
	  ;; and the 1st arg to `make-char' should be int.
	  (let ((default-mc-flag t))
	    (with-temp-buffer
	      (insert-char (make-char (symbol-value 'lc-jp)
				      40 44)
			   (/ (w3m-display-width) 2))
	      (buffer-string)))
	(make-string (/ (w3m-display-width) 2)
		     (make-char 'japanese-jisx0208 40 44)))
    (make-string (w3m-display-width) ?-)))

(defun w3m-about-header (url &optional no-decode no-cache &rest args)
  (when (string-match "\\`about://header/" url)
    (setq url (substring url (match-end 0)))
    (insert "Page Information\n"
	    "\nTitle:          " (or (w3m-arrived-title
				      (w3m-url-strip-authinfo url))
				     "")
	    "\nURL:            " url
	    "\nDocument Type:  " (or (w3m-content-type url) "")
	    "\nLast Modified:  "
	    (let ((time (w3m-last-modified url)))
	      (if time (current-time-string time) ""))
	    (let ((anchor (with-current-buffer w3m-current-buffer
			    (and (equal url w3m-current-url) (w3m-anchor)))))
	      (if anchor
		  (concat "\nCurrent Anchor: " anchor)
		"")))
    (let ((ct (w3m-arrived-content-type url))
	  (charset (w3m-arrived-content-charset url))
	  (separator (w3m-make-separator))
	  (case-fold-search t)
	  header ssl beg)
      (when (or ct charset)
	(insert "\n\n" separator "\n\nModifer Information\n")
	(insert "\nDocument Content-Type:  " (or ct ""))
	(insert "\nDocument Charset:       " (or charset "")))
      (when (and (not (w3m-url-local-p url))
		 (setq header (condition-case nil
				  (or (unless no-cache
					(w3m-cache-request-header url))
				      (w3m-process-with-wait-handler
					(w3m-w3m-dump-head url handler)))
				(w3m-process-timeout nil))))
	(insert "\n\n" separator "\n\nHeader Information\n\n" header)
	(goto-char (point-min))
	(when (re-search-forward "^w3m-ssl-certificate: " nil t)
	  (setq beg (match-end 0))
	  (forward-line)
	  (while (and (not (eobp)) (looking-at "^[ \t]"))
	    (forward-line))
	  (setq ssl (buffer-substring beg (point)))
	  (delete-region beg (point))
	  (goto-char beg)
	  (insert "SSL\n")
	  (goto-char (point-max))
	  (insert separator "\n\nSSL Information\n\n")
	  (setq beg (point))
	  (insert ssl)
	  (goto-char beg)
	  (while (re-search-forward "^\t" nil t)
	    (delete-char -1)
	    (when (looking-at "Certificate:")
	      (insert "\n"))))))
    "text/plain"))

(defun w3m-view-header ()
  "Display the header of the current page."
  (interactive)
  (if w3m-current-url
      (let ((w3m-prefer-cache t))
	(cond
	 ((string-match "\\`about://header/" w3m-current-url)
	  (w3m-goto-url (substring w3m-current-url (match-end 0))))
	 ((string-match "\\`about://source/" w3m-current-url)
	  (w3m-goto-url (concat "about://header/"
				(substring w3m-current-url (match-end 0))))
	  (setq truncate-lines nil))
	 ((string-match "\\`about:" w3m-current-url)
	  (error "Can't load a header for %s" w3m-current-url))
	 (t
	  (w3m-goto-url (concat "about://header/" w3m-current-url))
	  (setq truncate-lines nil))))
    (w3m-message "Can't view page header")))

(defvar w3m-about-history-max-indentation '(/ (* (window-width) 2) 3)
  "*Number used to limit the identation level when showing a history.
This value is evaluated whenever a history page is displayed by the
`w3m-about-history' command.  So, it can be any s-expression returning
a number.")

(defvar w3m-about-history-indent-level 4
  "*Number used to specify the indentation level when showing a history.
A history page is invoked by the `w3m-about-history' command.")

(defun w3m-about-history (&rest args)
  "Show a tree-structured history."
  (let (start history current)
    (with-current-buffer w3m-current-buffer
      (setq history w3m-history-flat
	    current (cadar w3m-history)))
    (insert "\
<head><title>URL history</title></head><body>
<h1>List of all the links you have visited in this session.</h1><pre>\n")
    (setq start (point))
    (when history
      (let ((form
	     (format
	      "%%0%dd"
	      (length
	       (number-to-string
		(apply 'max
		       (apply 'append
			      (mapcar
			       (function
				;; Don't use `caddr' here, since it won't
				;; be substituted by the compiler macro.
				(lambda (e)
				  (car (cdr (cdr e)))))
			       history)))))))
	    (cur (current-buffer))
	    (margin (if (> w3m-about-history-indent-level 1)
			1
		      0))
	    (max-indent (condition-case nil
			    ;; Force the value to be a number or nil.
			    (+ 0 (eval w3m-about-history-max-indentation))
			  (error nil)))
	    (last-indent -1)
	    (sub-indent 0)
	    element url about title position bol indent)
	(while history
	  (setq element (pop history)
		url (car element)
		;; FIXME: an ad-hoc workaround to avoid illegal-type errors.
		about (or (not (stringp url))
			  (string-match w3m-history-ignored-regexp url))
		title (plist-get (cadr element) :title)
		position (caddr element))
	  (when url
	    (insert (format "h%s %d %d <a href=\"%s\">%s%s%s %s</a>\n"
			    (mapconcat (function (lambda (d) (format form d)))
				       position
				       "-")
			    (/ (1- (length position)) 2)
			    (if (equal current position) 1 0)
			    url
			    (if about "&lt;" "")
			    (if (or (not title)
				    (string-equal "<no-title>" title)
				    (string-match "^[\t $B!!(B]*$" title))
				url
			      (w3m-encode-specials-string title))
			    (if about "&gt;" "")
			    position))))
	(sort-fields 0 start (point-max))
	(goto-char start)
	(while (not (eobp))
	  (setq bol (point))
	  (skip-chars-forward "^ ")
	  (setq indent (read cur)
		sub-indent (if (= indent last-indent)
			       (1+ sub-indent)
			     0)
		last-indent indent
		indent (+ (* w3m-about-history-indent-level indent)
			  sub-indent))
	  (when (prog1
		    (= (read cur) 1)
		  (delete-region bol (point))
		  (insert-char ?\  (+ margin (if max-indent
						 (min max-indent indent)
					       indent))))
	    (beginning-of-line)
	    (delete-char 1)
	    (insert "&gt;"))
	  (forward-line 1))))
    (insert "</pre></body>")
    "text/html"))

(defun w3m-about-db-history (url &rest args)
  (let ((start 0)
	(size nil)
	(width (- (w3m-display-width) 18))
	(now (current-time))
	title time alist prev next page total)
    (when (string-match "\\`about://db-history/\\?" url)
      (dolist (s (split-string (substring url (match-end 0)) "&"))
	(when (string-match "\\`\\(start\\|\\(size\\)\\)=" s)
	  (set (if (match-beginning 2) 'size 'start)
	       (string-to-number (substring s (match-end 0)))))))
    (when w3m-arrived-db
      (mapatoms
       (lambda (sym)
	 (and sym
	      (setq url (symbol-name sym))
	      (not (string-match "#" url))
	      (not (string-match w3m-history-ignored-regexp url))
	      (push (cons url (w3m-arrived-time url)) alist)))
       w3m-arrived-db)
      (setq alist (sort alist
			(lambda (a b)
			  (w3m-time-newer-p (cdr a) (cdr b))))))
    (setq total (length alist))
    (setq alist (nthcdr start alist))
    (when size
      (when (> start 0)
	(setq prev
	      (format "about://db-history/?start=%d&size=%d"
		      (max 0 (- start size)) size)))
      (when (> (length alist) size)
	(setq next
	      (format "about://db-history/?start=%d&size=%d"
		      (+ start size) size)))
      (when (> total 0)
	(setq total (+ (/ total size) (if (> (% total size) 0) 1 0)))
	(setq page (1+ (/ start size)))))
    (insert "<html><head><title>URL history in DataBase</title>"
	    (if prev (format "<link rel=\"prev\" href=\"%s\">\n" prev) "")
	    (if next (format "<link rel=\"next\" href=\"%s\">\n" next) "")
	    (format
	     "</head>\n<body>\n<h1>Arrived URL history in DataBase%s</h1>\n"
	     (if (and page total)
		 (format " (%d/%d)" page total) "")))
    (setq prev
	  (if (or prev next)
	      (setq next
		    (concat
		     "<p align=\"left\">"
		     (if prev
			 (format "[<a href=\"%s\">Prev History</a>]" prev)
		       "")
		     (if next
			 (format "[<a href=\"%s\">Next History</a>]" next)
		       "")
		     "</p>\n"))
	    ""))
    (if (null alist)
	(insert "<em>Nothing in DataBase.</em>\n")
      (insert prev "<table cellpadding=0>
<tr><td><h2> Title/URL </h2></td><td><h2>Time/Date</h2></td></tr>\n")
      (while (and alist
		  (or (not size)
		      (>= (decf size) 0)))
	(setq url (car (car alist))
	      time (cdr (car alist))
	      alist (cdr alist)
	      title (w3m-arrived-title url))
	(if (or (null title)
		(string= "<no-title>" title))
	    (setq title (concat "<" (w3m-truncate-string url width) ">"))
	  (when (>= (string-width title) width)
	    (setq title (concat (w3m-truncate-string title width) "..."))))
	(insert (format "<tr><td><a href=\"%s\">%s</a></td>"
			url
			(w3m-encode-specials-string title)))
	(when time
	  (insert "<td>"
		  (if (<= (w3m-time-lapse-seconds time now)
			  64800) ;; = (* 60 60 18) 18hours.
		      (format-time-string "%H:%M:%S" time)
		    (format-time-string "%Y-%m-%d" time))
		  "</td>"))
	(insert "</tr>\n"))
      (insert "</table>"
	      (if next "\n<br>\n<hr>\n" "")
	      prev))
    (insert "</body></html>\n"))
  "text/html")

(defun w3m-history-highlight-current-url (url)
  "Highlight the current url if it is a page for the history.
It does manage history position data as well."
  (when (string-equal "about://history/" url)
    (let ((inhibit-read-only t)
	  (buffer (current-buffer))
	  start)
      ;; Make history position data invisible.
      (goto-char (point-min))
      (w3m-next-anchor)
      (while (progn
	       (setq start (point))
	       (re-search-forward " (\\([0-9]+ \\)*[0-9]+)$" nil t))
	(goto-char (match-beginning 0))
	(put-text-property start (match-beginning 0)
			   'history-position (read buffer))
	(add-text-properties (match-beginning 0) (match-end 0)
			     '(invisible t intangible t))
	(forward-char 2)
	(skip-chars-forward "\t "))
      ;; Highlight the current url.
      (goto-char (point-min))
      (when (search-forward "\n>" nil t)
	(w3m-next-anchor)
	(setq start (point))
	(end-of-line)
	(put-text-property start (point) 'face 'w3m-history-current-url-face)
	(goto-char start)))
    (set-buffer-modified-p nil)))

(defcustom w3m-db-history-display-size
  (and (> w3m-keep-arrived-urls 500) 500)
  "*Maximum number of arrived URLs which are displayed per page."
  :group 'w3m
  :type '(radio (const :tag "All entries are displayed in single page." nil)
		(integer :format "%t: %v\n" :size 0)))

(defun w3m-db-history (&optional start size)
  "Display arrived URLs."
  (interactive
   (list nil w3m-db-history-display-size))
  (w3m-goto-url (concat
		 (format "about://db-history/?start=%d" (or start 0))
		 (if size (format "&size=%d" size) ""))))

(defun w3m-history (&optional arg)
  "Display the history of all the links you have visited in the session.
If it is called with the prefix argument, display the arrived URLs."
  (interactive "P")
  (if (null arg)
      (w3m-goto-url "about://history/")
    (w3m-db-history nil w3m-db-history-display-size)))

(defun w3m-w32-browser-with-fiber (url)
  (let ((proc (start-process "w3m-w32-browser-with-fiber"
			     (current-buffer)
			     "fiber.exe" "-s"
			     (if (w3m-url-local-p url)
				 (w3m-url-to-file-name url)
			       url))))
    (set-process-filter proc 'ignore)
    (set-process-sentinel proc 'ignore)))

;;; Interactive select buffer.
(defcustom w3m-select-buffer-horizontal-window t
  "*Non-nil means split windows horizontally to open the selection window."
  :group 'w3m
  :type 'boolean)

(defcustom w3m-select-buffer-window-ratio '(18 . 12)
  "*The percentage of the selection window to the whole frame.
The car is used when splitting windows horizontally and the cdr is for
splitting windows vertically."
  :group 'w3m
  :type '(cons (integer :format "H: %v[%%]  " :size 0)
	       (integer :format "V: %v[%%]\n" :size 0)))

(defvar w3m-select-buffer-window nil)
(defconst w3m-select-buffer-message
  "n: next buffer, p: previous buffer, q: quit."
  "Help message used when the emacs-w3m buffers selection window is open.")

;; Why this function is here abruptly is because of `w-s-b-horizontal-window'.
(defun w3m-display-width ()
  "Return the maximum width which should display lines within the value."
  (if (< 0 w3m-fill-column)
      w3m-fill-column
    (+ (if (and w3m-select-buffer-horizontal-window
		(get-buffer-window w3m-select-buffer-name))
	   ;; Show pages as if there is no buffers selection window.
	   (frame-width)
	 (window-width))
       (or w3m-fill-column -1))))

(defun w3m-select-buffer (&optional toggle nomsg)
  "Pop to the emacs-w3m buffers selection window up.
It provides the feature for switching emacs-w3m buffers using the
buffer list.  The following command keys are available:

\\{w3m-select-buffer-mode-map}"
  (interactive "P")
  (when toggle
    (setq w3m-select-buffer-horizontal-window
	  (not w3m-select-buffer-horizontal-window))
    (when (get-buffer-window w3m-select-buffer-name)
      (delete-windows-on w3m-select-buffer-name)))
  (cond ((eq major-mode 'w3m-mode)
	 (w3m-delete-frames-and-windows (selected-window))
	 (unless (get-buffer-window w3m-select-buffer-name)
	   (delete-other-windows)))
	((eq major-mode 'w3m-select-buffer-mode))
	(t
	 (let ((buffer (w3m-alive-p t)))
	   (if buffer
	       (w3m-popup-buffer buffer)
	     (w3m-goto-url (or w3m-home-page "about:"))))
	 (delete-other-windows)))
  (let ((selected-window (selected-window))
	(current-buffer (current-buffer)))
    (set-buffer (w3m-get-buffer-create w3m-select-buffer-name))
    (unless (eq nomsg 'update)
      (setq w3m-select-buffer-window selected-window))
    (let ((w (or (get-buffer-window w3m-select-buffer-name)
		 (split-window selected-window
			       (w3m-select-buffer-window-size)
			       w3m-select-buffer-horizontal-window))))
      (set-window-buffer w (current-buffer))
      (select-window w))
    (w3m-select-buffer-generate-contents current-buffer))
  (w3m-select-buffer-mode)
  (or nomsg (w3m-message w3m-select-buffer-message)))

(unless (fboundp 'w3m-update-tab-line)
  (defalias 'w3m-update-tab-line 'ignore))

(defun w3m-select-buffer-update (&rest args)
  (when (get-buffer-window w3m-select-buffer-name)
    (save-selected-window
      (w3m-select-buffer nil 'update)))
  (w3m-update-tab-line))

(defun w3m-select-buffer-generate-contents (current-buffer)
  (let (buffer-read-only)
    (delete-region (point-min) (point-max))
    (dolist (buffer (w3m-list-buffers))
      (put-text-property (point)
			 (progn
			   (insert (w3m-buffer-title buffer) "\n")
			   (point))
			 'w3m-select-buffer buffer))
    (skip-chars-backward " \t\r\f\n")
    (delete-region (point) (point-max))
    (set-buffer-modified-p nil)
    (goto-char (or (text-property-any (point-min) (point-max)
				      'w3m-select-buffer current-buffer)
		   (point-min)))))

(defvar w3m-select-buffer-mode-map nil)
(unless w3m-select-buffer-mode-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (substitute-key-definition
     'next-line 'w3m-select-buffer-next-line map global-map)
    (substitute-key-definition
     'previous-line 'w3m-select-buffer-previous-line map global-map)
    (substitute-key-definition
     'w3m-copy-buffer 'w3m-select-buffer-copy-buffer map w3m-mode-map)
    (substitute-key-definition
     'w3m-next-buffer 'w3m-select-buffer-next-line map w3m-mode-map)
    (substitute-key-definition
     'w3m-previous-buffer 'w3m-select-buffer-previous-line map w3m-mode-map)
    (substitute-key-definition
     'w3m-delete-buffer 'w3m-select-buffer-delete-buffer map w3m-mode-map)
    (substitute-key-definition
     'w3m-delete-other-buffers
     'w3m-select-buffer-delete-other-buffers map w3m-mode-map)
    (substitute-key-definition
     'w3m-scroll-up-or-next-url
     'w3m-select-buffer-show-this-line map w3m-mode-map)
    (substitute-key-definition
     'w3m-scroll-down-or-previous-url
     'w3m-select-buffer-show-this-line-and-down map w3m-mode-map)
    (substitute-key-definition
     'w3m-select-buffer 'w3m-select-buffer-toggle-style map w3m-mode-map)
    (define-key map " " 'w3m-select-buffer-show-this-line)
    (define-key map "g" 'w3m-select-buffer-recheck)
    (define-key map "j" 'w3m-select-buffer-next-line)
    (define-key map "k" 'w3m-select-buffer-previous-line)
    (define-key map "n" 'w3m-select-buffer-next-line)
    (define-key map "p" 'w3m-select-buffer-previous-line)
    (define-key map "q" 'w3m-select-buffer-quit)
    (define-key map "h" 'w3m-select-buffer-show-this-line-and-switch)
    (define-key map "w" 'w3m-select-buffer-show-this-line-and-switch)
    (define-key map "\C-m" 'w3m-select-buffer-show-this-line-and-quit)
    (define-key map "\C-c\C-c" 'w3m-select-buffer-show-this-line-and-quit)
    (define-key map "\C-c\C-k" 'w3m-select-buffer-quit)
    (define-key map "\C-c\C-q" 'w3m-select-buffer-quit)
    (define-key map "?" 'describe-mode)
    (setq w3m-select-buffer-mode-map map)))

(defun w3m-select-buffer-mode ()
  "Major mode for switching emacs-w3m buffers using the buffer list.

\\<w3m-select-buffer-mode-map>\
\\[w3m-select-buffer-next-line]\
	Next buffer.
\\[w3m-select-buffer-previous-line]\
	Previous buffer.

\\[w3m-select-buffer-show-this-line]\
	Show the buffer on the current menu line or scroll it up.
\\[w3m-select-buffer-show-this-line-and-down]\
	Show the buffer on the current menu line or scroll it down.
\\[w3m-select-buffer-show-this-line-and-switch]\
	Show the buffer on the menu and switch to the buffer.
\\[w3m-select-buffer-show-this-line-and-quit]\
	Show the buffer on the menu and quit the buffers selection.

\\[w3m-select-buffer-copy-buffer]\
	Create a copy of the buffer on the menu, and show it.
\\[w3m-select-buffer-delete-buffer]\
	Delete the buffer on the current menu line.
\\[w3m-select-buffer-delete-other-buffers]\
	Delete emacs-w3m buffers except for the buffer on the menu.

\\[w3m-select-buffer-toggle-style]\
	Toggle the style of the selection between horizontal and vertical.
\\[w3m-select-buffer-recheck]\
	Do the roll call to all emacs-w3m buffers.
\\[w3m-select-buffer-quit]\
	Quit the buffers selection.
"
  (setq major-mode 'w3m-select-buffer-mode
	mode-name "w3m buffers"
	truncate-lines t
	buffer-read-only t)
  (use-local-map w3m-select-buffer-mode-map)
  (run-hooks 'w3m-select-buffer-mode-hook))

(defun w3m-select-buffer-recheck ()
  "Do the roll call to all emacs-w3m buffers and regenerate the menu."
  (interactive)
  (let ((buffer-read-only nil))
    (erase-buffer))
  (w3m-select-buffer-generate-contents
   (window-buffer w3m-select-buffer-window))
  (w3m-select-buffer-show-this-line))

(defmacro w3m-select-buffer-current-buffer ()
  '(get-text-property (line-beginning-position) 'w3m-select-buffer))

(defun w3m-select-buffer-show-this-line (&optional interactive-p)
  "Show the buffer on the current menu line or scroll it up."
  (interactive (list t))
  (forward-line 0)
  (let ((obuffer (and (window-live-p w3m-select-buffer-window)
		      (window-buffer w3m-select-buffer-window)))
	(buffer (w3m-select-buffer-current-buffer)))
    (unless buffer
      (error "No buffer at point"))
    (cond
     ((get-buffer-window buffer)
      (setq w3m-select-buffer-window (get-buffer-window buffer)))
     ((window-live-p w3m-select-buffer-window)
      ())
     ((one-window-p t)
      (setq w3m-select-buffer-window (selected-window))
      (select-window
       (split-window nil
		     (w3m-select-buffer-window-size)
		     w3m-select-buffer-horizontal-window)))
     (t (setq w3m-select-buffer-window (get-largest-window))))
    (set-window-buffer w3m-select-buffer-window buffer)
    (when (and interactive-p (eq obuffer buffer))
      (save-selected-window
	(pop-to-buffer buffer)
	(w3m-scroll-up-or-next-url nil)))
    ;; FIXME: we should use a hook variable for this, maybe.
    (w3m-static-when (boundp 'header-line-format)
      (w3m-force-window-update w3m-select-buffer-window))
    (w3m-message w3m-select-buffer-message)
    buffer))

(defun w3m-select-buffer-show-this-line-and-down ()
  "Show the buffer on the current menu line or scroll it down."
  (interactive)
  (let ((obuffer (and (window-live-p w3m-select-buffer-window)
		      (window-buffer w3m-select-buffer-window)))
	(buffer (w3m-select-buffer-show-this-line)))
    (when (eq obuffer buffer)
      (save-selected-window
	(pop-to-buffer buffer)
	(w3m-scroll-down-or-previous-url nil)))))

(defun w3m-select-buffer-next-line (&optional n)
  "Move cursor vertically down N lines and show the buffer on the menu."
  (interactive "p")
  (forward-line n)
  (prog1
      (w3m-select-buffer-show-this-line)
    (w3m-static-when (featurep 'xemacs)
      (save-window-excursion
	;; Update gutter tabs.
	(select-window w3m-select-buffer-window)))))

(defun w3m-select-buffer-previous-line (&optional n)
  "Move cursor vertically up N lines and show the buffer on the menu."
  (interactive "p")
  (w3m-select-buffer-next-line (- n)))

(defun w3m-select-buffer-copy-buffer ()
  "Create a copy of the buffer on the current menu line, and show it."
  (interactive)
  (w3m-select-buffer-show-this-line)
  (let ((window (selected-window)))
    (select-window (get-buffer-window (w3m-select-buffer-current-buffer)))
    ;; The selection buffer will be updated automatically because
    ;; `w3m-copy-buffer' calls `w3m-select-buffer-update' by way of
    ;; `w3m-goto-url'.
    (w3m-copy-buffer)
    (select-window window)))

(defun w3m-select-buffer-delete-buffer (&optional force)
  "Delete the buffer on the current menu line.
If there is the sole emacs-w3m buffer, it is assumed to be called for
terminating the emacs-w3m session; the prefix argument FORCE will be
passed to the `w3m-quit' function (which see)."
  (interactive "P")
  (w3m-select-buffer-show-this-line)
  (if (= 1 (count-lines (point-min) (point-max)))
      (w3m-quit force)
    (let ((buffer (w3m-select-buffer-current-buffer)))
      (forward-line -1)
      (w3m-process-stop buffer)
      (kill-buffer buffer)
      (run-hooks 'w3m-delete-buffer-hook)
      (w3m-select-buffer-generate-contents (w3m-select-buffer-current-buffer))
      (w3m-select-buffer-show-this-line))))

(defun w3m-select-buffer-delete-other-buffers ()
  "Delete emacs-w3m buffers except for the buffer on the current menu."
  (interactive)
  (w3m-select-buffer-show-this-line)
  (w3m-delete-other-buffers (w3m-select-buffer-current-buffer)))

(defun w3m-select-buffer-quit ()
  "Quit the buffers selection."
  (interactive)
  (if (one-window-p t)
      (set-window-buffer (selected-window)
			 (or (w3m-select-buffer-current-buffer)
			     (w3m-alive-p)))
    (let ((buf (or (w3m-select-buffer-current-buffer)
		   (w3m-alive-p)))
	  pop-up-frames)
      (pop-to-buffer buf)
      (and (get-buffer-window w3m-select-buffer-name)
	   (delete-windows-on w3m-select-buffer-name)))))

(defun w3m-select-buffer-show-this-line-and-switch ()
  "Show the buffer on the menu and switch to the buffer."
  (interactive)
  (pop-to-buffer (w3m-select-buffer-show-this-line))
  (w3m-message ""))

(defun w3m-select-buffer-show-this-line-and-quit ()
  "Show the buffer on the menu and quit the buffers selection."
  (interactive)
  (w3m-select-buffer-show-this-line-and-switch)
  (and (get-buffer-window w3m-select-buffer-name)
       (delete-windows-on w3m-select-buffer-name)))

(defun w3m-select-buffer-close-window ()
  "Close the window which displays the buffers selection."
  (let ((window (get-buffer-window w3m-select-buffer-name)))
    (when window
      (if (one-window-p t)
	  (set-window-buffer window (other-buffer))
	(delete-window window)))))

(defun w3m-select-buffer-toggle-style()
  "Toggle the style of the selection between horizontal and vertical."
  (interactive)
  (w3m-select-buffer t))

(defun w3m-select-buffer-window-size ()
  (if w3m-select-buffer-horizontal-window
      (- (window-width)
	 (/ (* (frame-width) (car w3m-select-buffer-window-ratio)) 100))
    (- (window-height)
       (/ (* (frame-height) (cdr w3m-select-buffer-window-ratio)) 100))))


;;; Header line
(defcustom w3m-use-header-line t
  "*Non-nil means display the header line."
  :group 'w3m
  :type 'boolean)

(defface w3m-header-line-location-title-face
  '((((class color) (background light))
     (:foreground "Blue" :background "Gray90"))
    (((class color) (background dark))
     (:foreground "Cyan" :background "Gray20")))
  "Face used to highlight title when displaying location in the header line."
  :group 'w3m-face)

(defface w3m-header-line-location-content-face
  '((((class color) (background light))
     (:foreground "DarkGoldenrod" :background "Gray90"))
    (((class color) (background dark))
     (:foreground "LightGoldenrod" :background "Gray20")))
  "Face used to highlight url when displaying location in the header line."
  :group 'w3m-face)

(defvar w3m-header-line-map nil)
(unless w3m-header-line-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map w3m-mode-map)
    (define-key map [mouse-2] 'w3m-goto-url)
    ;; Prevent tool-bar from being doubled under Emacs 21.
    (define-key map [tool-bar] 'undefined)
    (setq w3m-header-line-map map)))

(defun w3m-header-line-insert ()
  "Put the header line into the current buffer."
  (when (and (or (featurep 'xemacs)
		 (< emacs-major-version 21)
		 (w3m-use-tab-p))
	     w3m-use-header-line
	     w3m-current-url
	     (eq 'w3m-mode major-mode))
    (goto-char (point-min))
    (let ((ct (w3m-arrived-content-type w3m-current-url))
	  (charset (w3m-arrived-content-charset w3m-current-url)))
      (insert (format "Location%s: " (cond ((and ct charset) " [TC]")
					   (ct " [T]")
					   (charset " [C]")
					   (t "")))))
    (w3m-add-text-properties (point-min) (point)
			     `(face w3m-header-line-location-title-face))
    (let ((start (point)))
      (insert w3m-current-url)
      (w3m-add-text-properties start (point)
			       `(face
				 w3m-header-line-location-content-face
				 mouse-face
				 highlight
				 ,(if (or (featurep 'xemacs)
					  (>= emacs-major-version 21))
				      'keymap
				    'local-map)
				 ,w3m-header-line-map
				 ,@(if (featurep 'xemacs)
				       '(help-echo
					 "button2 prompts to input URL"
					 balloon-help
					 "button2 prompts to input URL")
				     '(help-echo
				       "mouse-2 prompts to input URL"))))
      (setq start (point))
      (insert-char ?\  (max
			0
			(- (if (and w3m-select-buffer-horizontal-window
				    (get-buffer-window w3m-select-buffer-name))
			       (frame-width)
			     (window-width))
			   (current-column) 1)))
      (w3m-add-text-properties start (point)
			       '(face w3m-header-line-location-content-face))
      (unless (eolp)
	(insert "\n")))))


;;; w3m-minor-mode
(defvar w3m-goto-article-function nil
  "Function to visit an article pointed by a given URL.
A function set to this variable must accept an URL, and must return
non-nil when an article pointed by the URL is found.")

(defun w3m-safe-view-this-url ()
  "View the URL of the link under point.
This command is quite similar to `w3m-view-this-url' without three
differences: (1) this command accepts no arguments, (2) this command
does not handle forms, and (3) this command does not consider URL-like
strings under the cursor.  When a unsecure page which may contain
vicious forms is viewed, this command should be used instead of
`w3m-view-this-url'.

Note that this command depends on the value of `w3m-safe-url-regexp'
\(which see) to consider whether the URL is safe.  You need to keep in
mind that there may be pages which cause security problems.

This command makes a new emacs-w3m buffer if `w3m-make-new-session' is
non-nil and a user invokes this command in a buffer not being running
the `w3m-mode', otherwise use an existing emacs-w3m buffer."
  (interactive)
  (let ((w3m-pop-up-windows nil)
	(url (w3m-url-valid (w3m-anchor))))
    (cond
     (url (or (when (fboundp w3m-goto-article-function)
		(funcall w3m-goto-article-function url))
	      (if (and w3m-make-new-session
		       (not (eq major-mode 'w3m-mode)))
		  (w3m-goto-url-new-session url)
		(w3m-goto-url url))))
     ((w3m-url-valid (w3m-image))
      (if (w3m-display-graphic-p)
	  (w3m-toggle-inline-image)
	(w3m-view-image)))
     (t (w3m-message "No URL at point")))))

(defun w3m-mouse-safe-view-this-url (event)
  "Perform the command `w3m-safe-view-this-url' by the mouse event."
  (interactive "e")
  (mouse-set-point event)
  (w3m-safe-view-this-url))

(defun w3m-safe-toggle-inline-image (&optional force no-cache)
  "Toggle the visibility of an image under point.
This function is mostly equivalent to `w3m-toggle-inline-image', but
the value of `w3m-safe-url-regexp' is bound to \"\\\\`cid:\" while
displaying an image.  You can invalidate it (treat as nil) by
specifying the prefix argument if you don't mind it may cause a
security problem."
  (interactive "P")
  (let ((w3m-safe-url-regexp (unless (and force
					  (yes-or-no-p "\
Are you sure you really want to show this image (maybe unsecure)? "))
			       "\\`cid:")))
    (w3m-toggle-inline-image force no-cache)))

(defun w3m-safe-toggle-inline-images (&optional force no-cache)
  "Toggle the visibility of all images in the buffer.
This function is mostly equivalent to `w3m-toggle-inline-images', but
the value of `w3m-safe-url-regexp' is bound to \"\\\\`cid:\" while
displaying images.  You can invalidate it (treat as nil) by specifying
the prefix argument if you don't mind it may cause a security problem."
  (interactive "P")
  (let ((w3m-safe-url-regexp (unless (and force
					  (yes-or-no-p "\
Are you sure you really want to show all images (maybe unsecure)? "))
			       "\\`cid:")))
    (w3m-toggle-inline-images force no-cache)))

(defconst w3m-minor-mode-command-alist
  '((w3m-next-anchor)
    (w3m-previous-anchor)
    (w3m-next-image)
    (w3m-previous-image)
    (w3m-toggle-inline-image . w3m-safe-toggle-inline-image)
    (w3m-toggle-inline-images . w3m-safe-toggle-inline-images)
    (w3m-view-this-url . w3m-safe-view-this-url)
    (w3m-mouse-view-this-url . w3m-mouse-safe-view-this-url)
    (w3m-print-this-url))
  "Alist of commands and commands to be defined in `w3m-minor-mode-map'.
Each element looks like (FROM-COMMAND . TO-COMMAND); those keys which
are defined as FROM-COMMAND in `w3m-mode-map' are redefined as
TO-COMMAND in `w3m-minor-mode-map'.  When TO-COMMAND is nil,
FROM-COMMAND is defined in `w3m-minor-mode-map' with the same key in
`w3m-mode-map'.")

(defun w3m-make-minor-mode-keymap ()
  "Return a keymap used for `w3m-minor-mode'."
  (let ((keymap (make-sparse-keymap)))
    (dolist (pair w3m-minor-mode-command-alist)
      (substitute-key-definition (car pair)
				 (or (cdr pair) (car pair))
				 keymap w3m-mode-map))
    (unless (featurep 'xemacs)
      ;; Inhibit the `widget-button-click' command when
      ;; `w3m-imitate-widget-button' is activated.
      (define-key keymap [down-mouse-2] 'undefined))
    keymap))

(defvar w3m-minor-mode-map (w3m-make-minor-mode-keymap)
  "*Keymap used when `w3m-minor-mode' is active.")

(defcustom w3m-minor-mode-hook nil
  "*Hook run after `w3m-minor-mode' initialization."
  :group 'w3m
  :type 'hook)

(defvar w3m-minor-mode nil "Non-nil if w3m minor mode is enabled.")
(make-variable-buffer-local 'w3m-minor-mode)
(unless (assq 'w3m-minor-mode minor-mode-alist)
  (push (list 'w3m-minor-mode " w3m") minor-mode-alist))
(unless (assq 'w3m-minor-mode minor-mode-map-alist)
  (push (cons 'w3m-minor-mode w3m-minor-mode-map) minor-mode-map-alist))

(defun w3m-minor-mode (&optional arg)
  "Minor mode to view text/html parts in articles."
  (interactive "P")
  (when (setq w3m-minor-mode
	      (if arg
		  (> (prefix-numeric-value arg) 0)
		(not w3m-minor-mode)))
    (run-hooks 'w3m-minor-mode-hook)))


(provide 'w3m)

(unless noninteractive
  (if (string-match "\\.el\\'" w3m-init-file)
      (or (load (concat w3m-init-file "c") t t t)
	  (load w3m-init-file t t t))
    (load w3m-init-file t t))
  (run-hooks 'w3m-load-hook))

;;; w3m.el ends here
