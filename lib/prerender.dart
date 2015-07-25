library prerender;
import 'dart:html' as html;
import 'dart:math' as Math;
import 'dart:async';
import 'package:stagexl/stagexl.dart';

ResourceManager RESOURCES = new ResourceManager();
Stage STAGE = new Stage(new html.CanvasElement());

Sprite layer = new Sprite();
var loadOptions = new BitmapDataLoadOptions()
	..corsEnabled = true;

Map<String, BitmapData> deco = {};

BitmapPool pool = new BitmapPool();

class BitmapPool {
	List items = [];

	Bitmap take() {
		if (items.isEmpty)
			return new Bitmap();
		else {
			Bitmap bitmap = items.first;
			items.remove(bitmap);

			bitmap
				..removeCache()
				..bitmapData = null
				..pivotX = 0
				..pivotY = 0
				..x = 0
				..y = 0
				..rotation = 0;

			return bitmap;
		}
	}

	recycle(Bitmap bitmap) {
		bitmap.parent.removeChild(bitmap);
		items.add(bitmap);
	}
}

Future<Map> prerender(Map street) async {
	String dataUrl;

	Map results = {
		'tsid' : street['tsid'],
		'layers': {}
	};

	for (Map layerMap in street['dynamic']['layers'].values) {
		// Sort decos by z value
		List decoList = new List.from(layerMap['decos'])
			..sort((Map A, Map B) => A['z'].compareTo(B['z']));

		//load the bitmaps
		for (Map decoMap in decoList) {
			if (!RESOURCES.containsBitmapData(decoMap['filename'])) {
				RESOURCES.addBitmapData(decoMap['filename'],
				                        'http://childrenofur.com/locodarto/scenery/' + decoMap['filename'] + '.png',
				                        loadOptions);
			}
		}
		await RESOURCES.load();

		// Create and append decos
		for (Map decoMap in decoList) {
			if (!RESOURCES.containsBitmapData(decoMap['filename'])) {
				continue;
			}

			Bitmap printBitmap = pool.take();
			layer.addChild(printBitmap);

			printBitmap.bitmapData = RESOURCES.getBitmapData(decoMap['filename']);
			printBitmap.pivotX = printBitmap.width / 2;
			printBitmap.pivotY = printBitmap.height;
			printBitmap.x = decoMap['x'];
			printBitmap.y = decoMap['y'];

			// Set width
			if (decoMap['h_flip'] == true)
				printBitmap.width = -decoMap['w'];
			else
				printBitmap.width = decoMap['w'];
			// Set height
			if (decoMap['v_flip'] == true)
				printBitmap.height = -decoMap['h'];
			else
				printBitmap.height = decoMap['h'];

			if (decoMap['r'] != null) {
				printBitmap.rotation = decoMap['r'] * Math.PI / 180;
			}

			if (layerMap['name'] == 'middleground') {
				printBitmap.y += layerMap['h'];
				printBitmap.x += layerMap['w'] ~/ 2;
			}


			// Apply filters to layer
			layer.filters.clear();
			ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
			for (String filter in layerMap['filters'].keys) {
				if (filter == 'tintColor') {
					int color = layerMap['filters']['tintColor'];
					num amount = layerMap['filters']['tintAmount'];
					if (amount == null)
						layerFilter.adjustColoration(color);
					else
						layerFilter.adjustColoration(color, amount / 255);
				}
				if (filter == 'brightness') {
					layerFilter.adjustBrightness(layerMap['filters']['brightness'] / 255);
				}
				if (filter == 'saturation') {
					layerFilter.adjustSaturation(layerMap['filters']['saturation'] / 255);
				}
				if (filter == 'contrast') {
					layerFilter.adjustContrast(layerMap['filters']['contrast'] / 255);
				}
				if (filter == 'blur') {
					layer.filters.add(new BlurFilter(layerMap['filters']['blur']));
				}
			}
			layer.filters.add(layerFilter);
		}

		layer.applyCache(0, 0, layerMap['w'], layerMap['h']);
		dataUrl = new BitmapData.fromRenderTextureQuad(layer.cache).toDataUrl();
		layer.children.toList().forEach((Bitmap child) => pool.recycle(child));
		results['layers'][layerMap['name']] = dataUrl;
	}
	return results;
}