/*
    Copyright (C) 2012 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/

namespace BirdFont {

public class GlyphRange {
	
	public Gee.ArrayList<UniRange> ranges;
	
	/** Glyphs without a corresponding unicode value (ligatures). */
	public Gee.ArrayList<string> unassigned;
	
	uint32 len = 0;
	
	bool range_is_class = false;
	
	public GlyphRange () {
		ranges = new Gee.ArrayList<UniRange> ();
		unassigned = new Gee.ArrayList<string> ();
	}
	
	public bool is_class () {
		return range_is_class || len > 1;
	}
	
	public void set_class (bool c) {
		range_is_class = true;
	}
	
	public bool is_empty () {
		return len == 0;
	}
	
	public void empty () {
		unassigned.clear ();
		ranges.clear ();
		len = 0;
	}
	
	public unowned Gee.ArrayList<UniRange> get_ranges () {
		return ranges;
	}
		
	// TODO: complete localized alphabetical sort åäö is not the right order for example.
	public void sort () {
		ranges.sort ((a, b) => {
			UniRange first, next;
			bool r;
			
			first = (UniRange) a;
			next = (UniRange) b;
			
			r = first.start > next.start;
			return_val_if_fail (first.start != next.start, 0);
			
			return (r) ? 1 : -1;
		});
	}
	
	public void add_single (unichar c) {
		add_range (c, c);
	}
	
	public uint32 get_length () {
		uint32 l = len;
		l += unassigned.size;
		return l;
	}
	
	public void add_range (unichar start, unichar stop) {
		unichar b, s;
		if (unique (start, stop)) {
			append_range (start, stop);
		} else {
			
			// make sure this range does not overlap existing ranges
			b = start;
			s = b;
			if (!unique (b, b)) {			
				while (b < stop) {
					if (!unique (b, b)) {
						b++;
					} else {
						if (s != b) {
							add_range (b, stop);
						}
						
						b++;
						s = b;
					}
				}
			} else {
				while (b < stop) {
					if (unique (b, b)) {
						b++;
					} else {
						if (s != b) {
							add_range (start, b - 1);
						}
						
						b++;
						s = b;
					}
				}				
			}
		}
	}
	
	/** Parse ranges on the form a-z. Single characters can be added as well as 
	 * multiple ranges separated by space. The word "space" is used to kern against 
	 * the space character and the word "divis" is used to kern against "-".
	 * @param ranges unicode ranges
	 */
	public void parse_ranges (string ranges) throws MarkupError {
		parse_range_string (ranges);
	}
	
	private void parse_range_string (string ranges) throws MarkupError {
		string[] r;
				
		if (ranges == " ") {
			add_single (' ');
		}
		
		r = ranges.split (" ");
		
		foreach (string w in r) {
			w = w.replace (" ", "");
			
			if (w == "") {
				continue;
			}
			
			if (w.char_count () == 1) {
				add_single (w.get_char ());
			} else if (w == "space") {
				add_single (' ');
			} else if (w == "divis") {
				add_single ('-');
			} else if (w == "null") {
				add_single ('\0');
			} else if (w.index_of ("-") > -1) {
				parse_range (w);
			} else if (w == "quote") {
				add_single ('"');
			} else if (w == "ampersand") {
				add_single ('&');
			} else {
				throw new MarkupError.PARSE (@"$w is not a single letter or a unicode range.");
			}
		}
	}

	/** A readable representation of ranges, see parse_ranges for parsing 
	 * this string. This function is used for storing ranges in th .bf format.
	 */
	public string get_all_ranges () {
		bool first = true;
		StringBuilder s = new StringBuilder ();
		foreach (UniRange u in ranges) {
			
			if (!first) {
				s.append (" ");
			}
			
			if (u.start == u.stop) {
				s.append (get_serialized_char (u.start));
			} else {
				s.append (get_serialized_char (u.start));
				s.append ("-");
				s.append (get_serialized_char (u.stop));
			}
			
			first = false;
		}
		return s.str;
	}
	
	public static string serialize (string s) {
		
		if (s == "space") {
			return s;
		}

		if (s == "divis") {
			return s;
		}

		if (s == "null") {
			return s;
		}

		if (s == "quote") {
			return s;
		}

		if (s == "ampersand") {
			return s;
		}

		if (s == "&quot;") {
			return s;
		}

		if (s == "&amp;") {
			return s;
		}

		if (s == "&lt;") {
			return s;
		}

		if (s == "&gt;") {
			return s;
		}
									
		if (s.char_count () > 1) {
			warning (@"Expecting a single glyph ($s)");
			return s;
		}
		
		return get_serialized_char (s.get_char (0));
	}
	
	public static string get_serialized_char (unichar c) {
		StringBuilder s = new StringBuilder ();

		if (c == '&') {
			return "&amp;";
		}

		if (c == '<') {
			return "&lt;";
		}

		if (c == '>') {
			return "&gt;";
		}
		
		if (c == ' ') {
			return "space";
		}

		if (c == '-') {
			return "divis";
		}

		if (c == '\0') {
			return "null";
		}

		if (c == '"') {
			return "quote";
		}

		if (c == '&') {
			return "ampersand";
		}

		s.append_unichar (c);	
		return s.str;	
	}
	
	public static string unserialize (string c) {
		if (c == "&quot;") {
			return "\"";
		}

		if (c == "&amp;") {
			return "&";
		}

		if (c == "&lt;") {
			return "<";
		}

		if (c == "&gt;") {
			return ">";
		}
		
		if (c == "space") {
			return " ";
		}

		if (c == "divis") {
			return "-";
		}

		if (c == "null") {
			return "\0";
		}

		if (c == "quote") {
			return "\"";
		}

		if (c == "ampersand") {
			return "&";
		}
				
		return c;
	}
	
	private void parse_range (string s) throws MarkupError {
		string[] r = s.split ("-");
		bool null_range = false;
	
		if (r.length == 2 && r[0] == "null" && r[1] == "null") {
			null_range = true;
		} else if (r.length == 2 && r[0] == "null" &&  unserialize (r[1]).char_count () == 1) {
			null_range = true;
		} 
		
		if (!null_range) {
			if (r.length != 2
				|| unserialize (r[0]).char_count () != 1 
				|| unserialize (r[1]).char_count () != 1) {
				throw new MarkupError.PARSE (@"$s is not a valid range, it should be on the form A-Z.");
			}
		}
		
		append_range (unserialize (r[0]).get_char (), unserialize (r[1]).get_char ());
	}
	
	private void append_range (unichar start, unichar stop) {
		UniRange r;
		r = insert_range (start, stop); // insert a unique range
		merge_range (r); // join connecting ranges
	}
	
	private void merge_range (UniRange r) {
		Gee.ArrayList<UniRange> deleted = new Gee.ArrayList<UniRange>  ();
		Gee.ArrayList<UniRange> merged = new Gee.ArrayList<UniRange>  ();
		bool updated = false;
		
		foreach (UniRange u in ranges) {
			if (u == r) {
				continue;
			}
			
			if (u.start == r.stop + 1) {
				u.start = r.start;
				deleted.add (r);
				merged.add (u);
				break;
			}
			
			if (u.stop == r.start - 1) {
				u.stop = r.stop;
				deleted.add (r);
				merged.add (u);
				break;
			}
		}

		updated = merged.size > 0;

		foreach (UniRange m in deleted) {
			while (ranges.remove (m));
		}
				
		foreach (UniRange m in merged) {
			merge_range (m);
		}
		
		if (updated) {
			merge_range (r);
		}
	}

	public string get_char (uint32 index) {
		int64 ti;
		string chr;
		UniRange r;
		StringBuilder sb;
		unichar c;
		
		if (index > len + unassigned.size) {
			return "\0".dup();
		}
		
		if (index >= len) {
			if (index - len >= unassigned.size) {
				return "\0".dup();
			} 
			
			chr = unassigned.get ((int) (index - len));
			return chr;
		}

		r = ranges.get (0);
		ti = index;

		foreach (UniRange u in ranges) {
			ti -= u.length ();
			
			if (ti < 0) {
				r = u;
				break;
			}
		}
				
		sb = new StringBuilder ();
		c = r.get_char ((unichar) (ti + r.length ()));
		sb.append_unichar (c);

		return sb.str;
	}
	
	public uint32 length () {
		return len;
	}

	public bool has_character (string c) {
		unichar s;
		string uns = unserialize (c);
		
		if (uns.char_count () != 1) {
			warning (@"Expecting a single character got $c");
		}
		
		s = uns.get_char ();
		return !unique (s, s);
	}

	public bool has_unichar (unichar c) {
		return !unique (c, c);
	}
	
	private bool unique (unichar start, unichar stop) {
		foreach (UniRange u in ranges) {
			if (inside (start, u.start, u.stop)) {
				return false;
			}
			
			if (inside (stop, u.start, u.stop)) {
				return false;
			}
			
			if (inside (u.start, start, stop)) {
				return false;
			}
			
			if (inside (u.stop, start, stop)) {
				return false;
			}
		}

		return true;
	}

	private static bool inside (unichar start, unichar u_start, unichar u_stop) {
		return (u_start <= start <= u_stop);
	}
	
	private UniRange insert_range (unichar start, unichar stop) {
		if (unlikely (start > stop)) {
			warning ("start > stop");
			stop = start;
		}
		
		UniRange ur = new UniRange (start, stop);
		len += ur.length ();
		ranges.add (ur);
		
		return ur;
	}

	public void print_all () {
		stdout.printf ("Ranges:\n");
		stdout.printf (get_all_ranges ());
		stdout.printf ("\n");
	}
}

}
