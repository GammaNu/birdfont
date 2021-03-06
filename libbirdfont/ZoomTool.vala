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

class ZoomTool : Tool {

	int zoom_area_begin_x = -1;
	int zoom_area_begin_y = -1;
	
	int view_index = 0;
	List<Tab> views;
	
	public ZoomTool (string n) {
		base (n, "Zoom", 'z');

		views = new List<Tab> ();

		select_action.connect((self) => {
		});

		select_action.connect((self) => {
		});
			
		press_action.connect((self, b, x, y) => {
			if (b == 1 && KeyBindings.modifier != CTRL) {
				zoom_area_begin_x = x;
				zoom_area_begin_y = y;
			}
		});

		move_action.connect((self, x, y) => {
			Glyph g;
			
			if (zoom_area_begin_x > 0) {
				g = MainWindow.get_current_glyph ();
				g.show_zoom_area (zoom_area_begin_x, zoom_area_begin_y, x, y);
			}
		});
		
		release_action.connect((self, b, x, y) => {
			Glyph g;
						
			if (b == 1 && KeyBindings.modifier != CTRL) {
				store_current_view ();
				
				g =	MainWindow.get_current_glyph ();
				
				if (zoom_area_begin_x == x && zoom_area_begin_y == y) { // zero width center this point but don't zoom in
					g.set_center (x, y);
				} else { 
					g.set_zoom_from_area ();
				}
				
				zoom_area_begin_x = -1;
				zoom_area_begin_y = -1;
			}
		});
	}

	public void zoom_full_background_image () {
		BackgroundImage bg;
		Glyph g = MainWindow.get_current_glyph ();
		int x, y;
		
		if (g.get_background_image () == null) {
			return;
		}
		
		bg = (!) g.get_background_image ();
		
		x = (int) (bg.img_offset_x);
		y = (int) (bg.img_offset_y);
		
		g.set_zoom_area (x, y, (int) (x + bg.size_margin * bg.img_scale_x), (int) (y + bg.size_margin * bg.img_scale_y));
		g.set_zoom_from_area ();
	}

	public void zoom_full_glyph () {
		store_current_view ();
		
		MainWindow.get_current_display ().zoom_min ();
	}
	
	/** Add an item to zoom view list. */
	public void store_current_view () {	
		if (views.length () - 1 > view_index) {
			unowned List<Tab> i = views.nth (view_index + 1);
			while (i != i.last ()) {
				i.delete_link (i.next);
			}
		}
		
		views.append (MainWindow.get_current_tab ());
		view_index = (int)views.length () - 1;
		MainWindow.get_current_display ().store_current_view ();
	}

	/** Redo last zoom.*/
	public void next_view () {
		if (view_index + 1 >= (int) views.length ()) {
			return;
		}
		
		view_index++;
	
		MainWindow.select_tab (views.nth (view_index).data);
		MainWindow.get_current_display ().next_view ();
		GlyphCanvas.redraw ();
	}
	
	/** Undo last zoom. */
	public void previous_view () {
		if (view_index == 0) {
			return;
		}
		
		view_index--;
	
		MainWindow.select_tab (views.nth (view_index).data);
		MainWindow.get_current_display ().restore_last_view ();
		GlyphCanvas.redraw ();
	}
}
	
}
