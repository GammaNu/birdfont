/*
    Copyright (C) 2014 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/

using Cairo;
using Math;

namespace BirdFont {

public class StrokeTool : Tool {
	
	public StrokeTool (string tooltip) {
		select_action.connect((self) => {
			stroke_selected_paths ();
		});
	}
	
	public static void set_stroke_for_selected_paths (double width) {
		Glyph g = MainWindow.get_current_glyph ();
		
		foreach (Path p in g.active_paths) {
			p.set_stroke (width);
		}
		
		GlyphCanvas.redraw ();
	}

	/** Create strokes for the selected outlines. */
	void stroke_selected_paths () {
		Glyph g = MainWindow.get_current_glyph ();
		PathList paths = new PathList ();
		
		foreach (Path p in g.active_paths) {
			paths.append (get_stroke (p, p.stroke));
		}
		
		foreach (Path np in paths.paths) {
			g.add_path (np);
		}
	}
	
	public static PathList get_stroke (Path path, double thickness) {
		Path p = path.copy ();
		PathList pl;

		pl = get_stroke_outline (p, thickness);	
		
		return pl;	
	}
	
	public static PathList get_stroke_outline (Path p, double thickness) {
		Path counter, outline, merged;
		PathList paths = new PathList ();
				
		if (!p.is_open () && p.is_filled ()) {
			outline = create_stroke (p, thickness);
			outline.close ();
			paths.add (outline);
			outline.update_region_boundaries ();
		} else if (!p.is_open () && !p.is_filled ()) {
			outline = create_stroke (p, thickness);
			counter = create_stroke (p, -1 * thickness);
			
			paths.add (outline);
			paths.add (counter);
			
			if (p.is_clockwise ()) {
				outline.force_direction (Direction.CLOCKWISE);
			} else {
				outline.force_direction (Direction.COUNTER_CLOCKWISE);
			}
			
			if (outline.is_clockwise ()) {
				counter.force_direction (Direction.COUNTER_CLOCKWISE);
			} else {
				counter.force_direction (Direction.CLOCKWISE);
			}
			
			outline.update_region_boundaries ();
			counter.update_region_boundaries ();
		} else if (p.is_open ()) {
			outline = create_stroke (p, thickness);
			counter = create_stroke (p, -1 * thickness);
			merged = merge_strokes (p, outline, counter, thickness);
			
			if (p.is_clockwise ()) {
				merged.force_direction (Direction.CLOCKWISE);
			} else {
				merged.force_direction (Direction.COUNTER_CLOCKWISE);
			}
			
			merged.update_region_boundaries ();
			paths.add (merged);
		} else {
			warning ("Can not create stroke.");
			paths.add (p);
		}

		return paths;
	}
	
	/** Create one stroke from the outline and counter stroke and close the 
	 * open endings.
	 * 
	 * @param path the path to create stroke for
	 * @param stroke for the outline of path
	 * @param stroke for the counter path
	 */
	static Path merge_strokes (Path path, Path stroke, Path counter, double thickness) {
		Path merged;
		EditPoint corner1, corner2;
		EditPoint corner3, corner4;
		EditPoint end;
		double angle;
		
		if (path.points.size < 2) {
			warning ("Missing points.");
			return stroke;
		}
		
		if (stroke.points.size < 4) {
			warning ("Missing points.");
			return stroke;
		}

		if (counter.points.size < 4) {
			warning ("Missing points.");
			return stroke;
		}
				
		// end of stroke
		end = path.get_last_visible_point ();
		corner1 = stroke.get_last_point ();
		angle = end.get_left_handle ().angle;
		corner1.x = end.x + cos (angle - PI / 2) * thickness;
		corner1.y = end.y + sin (angle - PI / 2) * thickness;		

		corner2 = counter.get_last_point ();
		corner2.x = end.x + cos (angle + PI / 2) * thickness;
		corner2.y = end.y + sin (angle + PI / 2) * thickness;

		// the other end
		end = path.get_first_point ();
		corner3 = stroke.get_first_point ();
		angle = end.get_right_handle ().angle;
		corner3.x = end.x + cos (angle + PI / 2) * thickness;
		corner3.y = end.y + sin (angle + PI / 2) * thickness;		

		corner4 = counter.get_first_point ();
		corner4.x = end.x + cos (angle - PI / 2) * thickness;
		corner4.y = end.y + sin (angle - PI / 2) * thickness;
		
		corner1.get_left_handle ().convert_to_line ();
		corner2.get_right_handle ().convert_to_line ();
		
		corner3.get_left_handle ().convert_to_line ();
		corner4.get_right_handle ().convert_to_line ();
				
		counter.reverse ();

		// Append the other part of the stroke
		merged = stroke.copy ();
		merged.append_path (counter);
		corner2 = merged.points.get (merged.points.size - 1);
		
		merged.close ();
		merged.create_list ();
		merged.recalculate_linear_handles ();
						
		return merged;
	}
	
	static Path create_stroke (Path p, double thickness) {
		Path stroked;
		
		if (p.points.size >= 2) {
			stroked = p.copy ();
			add_corners (stroked);
			stroked = change_stroke_width (stroked, thickness);

			if (!p.is_open ()) {
				stroked.reverse ();
				stroked.close ();
			}
		} else {
			// TODO: create stroke for path with one point
			warning ("One point.");
			stroked = new Path ();
		}
		
		return stroked;
	}
	
	static void add_corners (Path p) {
		// TODO:
	}

	static Path change_stroke_width (Path original, double thickness) {
		Path stroked = new Path ();		
		EditPoint ep;
		uint k;
		uint npoints;
		Path new_path = original.copy ();

		EditPoint np, sp, nprev, sprev;
			
		int i = 0;
			
		double la, qx, qy;

		EditPoint split_point = new EditPoint ();
		EditPoint start, stop, new_start;
		EditPoint stroke_start, stroke_stop;
		EditPoint segment_start, segment_stop;
		EditPointHandle r, l;
		double left_x, left_y;
		bool new_point = false;
		double m, n;
		bool bad_segment = false;
		bool failed = false;
		int size;
		
		//FIXME: DELETE. add_self_intersection_points (new_path);
		
		new_path.remove_points_on_points ();
		new_path.update_region_boundaries ();

		k = 0;
		npoints = new_path.points.size;
		
		if (npoints < 2) {
			warning ("npoints < 2");
			return new_path;
		}
		
		left_x = 0;
		left_y = 0;
		start = new_path.get_first_point ();
		int it = 0;

		foreach (EditPoint e in new_path.points) {
			e.flags |= EditPoint.CORNER;
		}
		
		// double points are not good for this purpose, convert them to the quadratic form
		new_path.add_hidden_double_points (); 

		// add tangent points to the path
		segment_start = new_path.get_first_point ();
		size = new_path.points.size;
		
		for (int j = 0; j < size; j++) {
			segment_stop = segment_start.get_next ();
			Path.all_of (segment_start, segment_stop, (x, y, t) => {
				if (t == 0 && t != 1) {
					return true;
				}
				
				split_point = new EditPoint (x, y);
				
				split_point.prev = segment_start;
				split_point.next = segment_stop;
				
				segment_start.next = split_point;
				segment_stop.prev = split_point;
				
				new_path.insert_new_point_on_path (split_point, t);

				return false;
			}, 2);
			
			segment_start = segment_stop;
		}
		new_path.remove_points_on_points ();
		
		// calculate offset
		bad_segment = false;
		EditPoint previous_start = new EditPoint ();
		for (int points_to_process = new_path.points.size - 1; points_to_process >= 0; points_to_process--) {

			if (++it > 1000) { // FIXME: delete
				warning ("Skipping the rest of the path.");
				break;
			}
			
			if (is_null (start) || start.next == null) {
				warning ("No next point");
				break;
			}
			
			stop = start.get_next ();

			if (stop.type == PointType.NONE) {
				break;
			}

			// move point
			stroke_start = start.copy ();
			stroke_stop = stop.copy ();
			
			stroke_start.set_tie_handle (false);
			stroke_stop.set_tie_handle (false);
			
			start.set_tie_handle (false);
			stop.set_tie_handle (false);
			
			// FIXME: first point?
			stroke_start.get_left_handle ().move_to_coordinate_delta (left_x, left_y);
			
			r = stroke_start.get_right_handle ();
			l = stroke_stop.get_left_handle ();
			
			m = cos (r.angle + PI / 2) * thickness;
			n = sin (r.angle + PI / 2) * thickness;
			
			stroke_start.independent_x += m;
			stroke_start.independent_y += n;
			
			stroke_start.get_right_handle ().move_to_coordinate_delta (m, n);
			
			la = l.angle;
			qx = cos (la - PI / 2) * thickness;
			qy = sin (la - PI / 2) * thickness;

			left_x = qx;
			left_y = qy;
			stroke_stop.get_left_handle ().move_to_coordinate_delta (left_x, left_y);
			
			stroke_stop.independent_x += qx;
			stroke_stop.independent_y += qy;

			// avoid jagged edges
			double dar = stroke_start.get_right_handle ().angle - start.get_right_handle ().angle;
			double dal = stroke_stop.get_left_handle ().angle - stop.get_left_handle ().angle;

			if (fabs (dal) > 1) {
				stroke_stop.get_left_handle ().angle = stop.get_left_handle () .angle;
			}
				
			if (fabs (dar) > 1) {
				print ("FIX:");
				stroke_start.get_right_handle ().angle = start.get_right_handle () .angle;
			}

			// Create a segment of the stroked path
			Gee.ArrayList<EditPoint> on_stroke = new Gee.ArrayList<EditPoint> ();
			int n_samples = 0;
			Path.all_of (stroke_start, stroke_stop, (x, y, t) => {
				if (t == 0 || t == 1) {
					return true;
				}
				
				if (n_samples >= 2) {
					return false;
				}
				
				on_stroke.add (new EditPoint (x, y));
				n_samples++;
				return true;
			}, 3);
			
			if (on_stroke.size != 2) {
				warning (@"on_stroke.size: $(on_stroke.size)");
				return stroked;
			}
			
			// compare the outline of the stroke to the original path and 
			// add new points if offset differs from stroke width
			i = 0;
			new_point = false;
			if (!bad_segment) {
				Path.all_of (start, stop, (x, y, t) => {
					double d;
					EditPoint point_on_stroke;
					double stroke_width = fabs (thickness);
					
					if (t == 0 || t == 1) {
						return true;
					}
					
					if (i >= on_stroke.size) {
						warning (@"Out of bounds. ($i >= $(on_stroke.size)) t: $t");
						return false;
					}
					
					point_on_stroke = on_stroke.get (i++); 
					d = fabs (Path.distance (point_on_stroke.x, x, point_on_stroke.y, y) - stroke_width);
					split_point = new EditPoint (x, y);
					
					if (d > 1) {
						bad_segment = true; // add more points
						return false;
					}
					
					if (d > 0.2) {
						split_point.prev = start;
						split_point.next = stop;
						
						start.next = split_point;
						stop.prev = split_point;
						
						if (start.x == split_point.x && start.y == split_point.y) {
							warning (@"Point already added.  Error: $d");
							bad_segment = true;
							failed = true;
							return false;
						} else {
							new_path.insert_new_point_on_path (split_point, t);
							new_point = true;
						}
					}
					return !new_point;
				}, 3);
				
				/*
				// FIXME: add many points
				// bad segment
				if (bad_segment) {
					EditPoint first_split_point = new EditPoint ();
					bool first = true;
					Path.all_of (start, stop, (x, y, t) => {
						
						if (t == 0 || t == 1) {
							return true;
						}
						
						print ("add ... \n");
						split_point = new EditPoint (x, y);
						
						if (first) {
							first_split_point = split_point;
							first = false;
						}

						split_point.prev = start;
						split_point.next = stop;
						
						start.next = split_point;
						stop.prev = split_point;
						
						if (start.x == split_point.x && start.y == split_point.y) {
							warning (@"Point already added.");
							return false;
						} else {
							new_path.insert_new_point_on_path (split_point, t);
							new_point = true;
						}
							
						return !new_point;
					}, 6);
					
					la = first_split_point.get_left_handle ().angle;
					left_x = cos (la - PI / 2) * thickness;
					left_y = sin (la - PI / 2) * thickness;
				
					points_to_process += 5; // FIXME
					new_start = start;
				}
				*/
			}
			
			if (failed) {
				return stroked;
			}
			
			if (!new_point) {
				ep = stroke_start.copy ();
				stroked.add_point (ep);
				previous_start = stroke_start;
				new_start = stop; 
			} else {
				la = split_point.get_left_handle ().angle;
				qx = cos (la - PI / 2) * thickness;
				qy = sin (la - PI / 2) * thickness;
				left_x = qx;
				left_y = qy;
			
				points_to_process += 2; // process the current point and the new point
				new_start = start;
			}
			
			start = new_start;
		}
		
		new_path.remove_deleted_points ();
		if (!(stroked.points.size == new_path.points.size && new_path.points.size > 1)) {
			warning (@"stroked.points.size == new_path.points.size: $(stroked.points.size) != $(new_path.points.size)");
			return stroked;
		}

		// delete end point
		if (new_path.points.size > 2 && stroked.points.size > 2) {
			stroked.delete_last_point ();
			new_path.delete_last_point ();
			
			l = new_path.get_last_point ().get_left_handle ();

			stroked.get_last_point ().get_left_handle ().angle = l.angle;
			stroked.get_last_point ().get_left_handle ().length = l.length;
			stroked.get_last_point ().get_left_handle ().type = l.type;
			
			//stroked.get_last_point ().get_right_handle ().convert_to_line ();
			//stroked.get_first_point ().get_left_handle ().convert_to_line ();
		}
		
		// remove self intersection

		EditPoint snext, nnext;
		double back_ratio = 0;	
		double next_ratio = 0;
		
		snext = new EditPoint ();
		nnext = new EditPoint ();
		
		print (@"\n");
		/*
		for (int index = 1; index < stroked.points.size; index++) {
			np = new_path.points.get (index);
			sp = stroked.points.get (index);

			if (np.type == PointType.NONE) {
				break;
			}

			if (index < stroked.points.size - 1) {
				nnext = new_path.points.get (index + 1);
				snext = stroked.points.get (index + 1);
			}
			
			double inter_x, inter_y;
			double first_inter_x, first_inter_y;
			if (segment_intersects (stroked, sp, snext, out first_inter_x, out first_inter_y) && !sp.deleted) {
				print (@"n----- $index    $(sp.x), $(sp.y)\n");
			
				if (has_end_of_intersection (stroked, index + 1, first_inter_x, first_inter_y)) {
					for (int j = index + 1; j < stroked.points.size; j++) {
						np = new_path.points.get (j);
						sp = stroked.points.get (j);

						print (@"del ---- $j    $(sp.x), $(sp.y)\n");

						if (j < stroked.points.size - 1) {
							nnext = new_path.points.get (j + 1);
							snext = stroked.points.get (j + 1);
						}
						
						if ((nnext.flags & EditPoint.INTERSECTION) > 0
							|| (segment_intersects (stroked, sp, snext, out inter_x, out inter_y)
									&& Path.distance (first_inter_x, inter_x, first_inter_y, inter_y) < 0.1)) {
								print (@"done\n");
								index = j +1;
								break;
						} else {
							np.deleted = true;
							sp.deleted = true;
						}
					}
				} else {
					warning ("Failed to remove self intersection.");
				}
			}
		}
		*/


		foreach (EditPoint e in new_path.points) {
			if ((e.flags & EditPoint.CORNER) > 0) {
				//e.flags |= EditPoint.DELETED;
			}
		}

		foreach (EditPoint e in stroked.points) {
			if ((e.flags & EditPoint.CORNER) > 0) {
				//e.flags |= EditPoint.DELETED;
			}
		}
		
		stroked.remove_deleted_points ();
		new_path.remove_deleted_points ();
		
		return_val_if_fail (stroked.points.size == new_path.points.size, stroked);
				
		// adjust angle and length of control point handles
		double last_ratio = 0; // FIXME: FIRST POINT
		
		double last_prev_ratio = 0;

		double ratio = 0;
		
		nprev = new_path.points.get (new_path.points.size - 1);
		sprev = stroked.points.get (stroked.points.size - 1);
		for (int index = 0; index < stroked.points.size; index++) {
			np = new_path.points.get (index);
			sp = stroked.points.get (index);
			
			if (index < stroked.points.size - 1) {
				nnext = new_path.points.get (index + 1);
				snext = stroked.points.get (index + 1);
			}
			
			if (np.type == PointType.NONE || nnext.type == PointType.NONE) {
				break;
			}
						
			// angle
			double dar = sp.get_right_handle ().angle - np.get_right_handle ().angle;
			double dal = sp.get_left_handle ().angle - np.get_left_handle ().angle;

			if (fabs (dal) > 1) { // FIXME 0.1? PI?
				sp.get_left_handle ().angle = np.get_left_handle () .angle;
			}
				
			if (fabs (dar) > 1) {
				print (@"FIX:  $(sp) $(np)");
				sp.get_right_handle ().angle = np.get_right_handle () .angle;
			}

			sp.get_left_handle ().angle = np.get_left_handle () .angle;
			sp.get_right_handle ().angle = np.get_right_handle () .angle;
			
			// length
			next_ratio = Path.distance (snext.x, sp.x, snext.y, sp.y);
			next_ratio /=  Path.distance (nnext.x, np.x, nnext.y, np.y);

			back_ratio = Path.distance (sprev.x, sp.x, sprev.y, sp.y);
			back_ratio /=  Path.distance (nprev.x, np.x, nprev.y, np.y);
				
			// DELETE nsratio = (next_ratio + last_ratio + nsratio) / 3;
				
			//FIXME: false ...
			if (!(0.0002 < next_ratio < fabs (thickness)
				&& 0.0002 < back_ratio < fabs (thickness))) {
				print (@"BAD next_ratio $next_ratio\n");
				print (@"BAD back_ratio $back_ratio\n");

				ratio = last_ratio;
				sp.get_right_handle ().length = Path.distance (snext.x, sp.x, snext.y, sp.y); // HANDLE TYPE
				
				ratio = last_ratio;
				sp.get_left_handle ().length = Path.distance (snext.x, sp.x, snext.y, sp.y);
			} else {
				ratio = next_ratio;
				sp.get_right_handle ().length *= ratio;
				
				ratio = back_ratio;
				sp.get_left_handle ().length *= ratio;

				last_ratio = next_ratio; 
				last_prev_ratio = back_ratio;					
			}

			nprev = np;
			sprev = sp;
		}
		
		stroked.set_stroke (0);

		return stroked;
	}

/*	
	static void add_self_intersection_points (Path path) {
		Gee.ArrayList<EditPoint> n = new Gee.ArrayList<EditPoint> ();
		
		path.all_segments ((ep1, ep2) => {
			double ix, iy;
			EditPoint nep;
			
			if (segment_intersects (path, ep1, ep2, out ix, out iy)) {
				nep = new EditPoint ();
				nep.prev = ep1;
				nep.next = ep2;
				
				nep.x = ix;
				nep.y = iy;
				
				n.add (nep);
			}
			
			return true;
		});
		
		foreach (EditPoint np in n) {
			path.insert_new_point_on_path (np, -1, true);
			np.type = PointType.QUADRATIC;
			np.flags |= EditPoint.INTERSECTION;
		}
	}
*/

/*
	static bool segment_intersects (Path path, EditPoint ep, EditPoint next,
		out double ix, out double iy) {
		EditPoint p1, p2;
		double cross_x, cross_y;
		
		ix = 0;
		iy = 0;
				
		if (path.points.size == 0) {
			return false;
		}
		
		for (int i = 1; i < path.points.size - 2; i++) {
			p1 = path.points.get (i - 1);
			p2 = path.points.get (i);
			
			Path.find_intersection_point (ep, next, p1, p2, out cross_x, out cross_y);
	
			if ((p1.x < cross_x < p2.x || p1.x > cross_x > p2.x)
				&& (p1.y < cross_y < p2.y || p1.y > cross_y > p2.y)
				&& (ep.x < cross_x < next.x || ep.x > cross_x > next.x)
				&& (ep.y < cross_y < next.y || ep.y > cross_y > next.y)) {
					
					// iterate to find intersection.
					
					ix = cross_x;
					iy = cross_y;
				return true;
			}
		}
		
		return false;
	}
	

	static bool has_end_of_intersection (Path p, int start, double x, double y) {
		double inter_x, inter_y;
		EditPoint ep, next;
		
		next = new EditPoint ();
		for (int j = start; j < p.points.size - 1; j++) {
			ep = p.points.get (j);

			if (j < p.points.size - 1) {
				next = p.points.get (j + 1);
			}
			
			if (segment_intersects (p, ep, next, out inter_x, out inter_y)
				&& Path.distance (x, inter_x, y, inter_y) < 0.1) {
					return true;
			}
		}
		
		return false;
	}
	*/
}

}
