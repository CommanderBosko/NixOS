"""Parse human-written durations ("1h30m", "90s", "2d 4h") into seconds."""


def parse_duration(text):
    """Return the number of whole seconds described by ``text``.

    Grammar
    -------
    * A duration is one or more *components*. A component is an unsigned
      integer (ASCII digits 0-9 only) immediately followed by a unit letter,
      with no space between the number and the unit:

          d = 86400 seconds, h = 3600, m = 60, s = 1

      Unit letters are case-insensitive ("1H" == "1h").
    * Components may be written together ("1h30m") or separated by any amount
      of whitespace ("1h 30m", "1h\\t30m").
    * Leading and trailing whitespace is ignored.
    * Each unit may appear at most once, and units must appear in the order
      d, h, m, s (you may skip units: "1d 5m" is fine).
    * A component may exceed its natural range: "90m" is 5400, "36h" is 129600.
    * A bare integer with no unit means seconds, but only when it is the whole
      input (after trimming): "90" is 90.
    * "0s" and "0" are valid and return 0.

    Errors
    ------
    Raise ``TypeError`` if ``text`` is not a ``str``.

    Raise ``ValueError`` for anything else that does not match the grammar,
    including:
      * an empty or whitespace-only string
      * an unknown unit or any other stray character ("5x", "1h!", "1h,30m")
      * a sign or a decimal point ("-5m", "+5m", "1.5h")
      * a unit with no number ("h") or a space between number and unit ("1 h")
      * a unitless number alongside other components ("1h 30")
      * a repeated unit ("1h 1h") or units out of order ("30m 1h")

    Examples
    --------
    >>> parse_duration("1h30m")
    5400
    >>> parse_duration("2d 4h")
    187200
    >>> parse_duration("90")
    90
    """
    raise NotImplementedError
