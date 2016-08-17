library prerender;

import 'dart:html';
import 'dart:math' as Math;
import 'dart:async';
import 'package:stagexl/stagexl.dart';

ResourceManager RESOURCES = new ResourceManager();
Stage STAGE = new Stage(new CanvasElement());

var loadOptions = new BitmapDataLoadOptions()
	..corsEnabled = true;

Map<String, BitmapData> deco = {};

Sprite layer = new Sprite();
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

	Rectangle bounds = new Rectangle(street['dynamic']['l'],
			               			 street['dynamic']['t'],
			              			 street['dynamic']['l'].abs() + street['dynamic']['r'].abs(),
			               			(street['dynamic']['t'] - street['dynamic']['b']).abs());

	int groundY = -(street['dynamic']['ground_y'] as num).abs();

	DivElement layers = querySelector('#LayerWindow');

	/* //// Gradient Canvas //// */
	DivElement gradientCanvas = new DivElement();

	// Color the gradientCanvas
	String top = street['gradient']['top'];
	String bottom = street['gradient']['bottom'];

	gradientCanvas
		..classes.add('streetcanvas')
		..id = 'gradient'
		..attributes['ground_y'] = "0"
		..attributes['width'] = bounds.width.toString()
		..attributes['height'] = bounds.height.toString();
	gradientCanvas.style
		..zIndex = (-100).toString()
		..width = bounds.width.toString() + "px"
		..height = bounds.height.toString() + "px"
		..position = 'absolute'
		..background = 'linear-gradient(to bottom, #$top, #$bottom)';

	// Append it to the screen*/
	layers.append(gradientCanvas);

	for (Map layerMap in street['dynamic']['layers'].values) {
		// Sort decos by z value
		List decoList = new List.from(layerMap['decos'])
			..sort((Map A, Map B) => A['z'].compareTo(B['z']));

		//load the bitmaps
		for (Map decoMap in decoList) {
			if (!RESOURCES.containsBitmapData(decoMap['filename'])) {
				RESOURCES.addBitmapData(decoMap['filename'],
				                        'http://childrenofur.com/locodarto/scenery/' + decoMap['filename'],
				                        loadOptions);
			}
		}

		try {
			await RESOURCES.load();
		} catch (e) {
//			print('error: $e');
		}

		//Create and append decos
		for (Map decoMap in decoList) {
			List<String> failedNames = [];
			RESOURCES.failedResources.forEach((ResourceManagerResource resource) => failedNames.add(resource.name));

			if (!RESOURCES.containsBitmapData(decoMap['filename']) ||
			    failedNames.contains(decoMap['filename'])) {
				continue;
			}

			Deco deco = new Deco(decoMap);
			if (layerMap['name'] == 'middleground') {
				//middleground has different layout needs
				deco.y += layerMap['h'];
				deco.x += layerMap['w'] ~/ 2;
			}
			layer.addChild(deco);
		}

		applyFilters(layerMap);

		layer.applyCache(0, 0, layerMap['w'], layerMap['h']);
		dataUrl = new BitmapData.fromRenderTextureQuad(layer.cache).toDataUrl();
		ImageElement image = new ImageElement(src:dataUrl);
		image.style.position = 'absolute';
		image.style.zIndex = layerMap['z'].toString();
		layers.append(image);
		layer.removeChildren();
		results['layers'][layerMap['name']] = dataUrl;
	}

	return results;
}

void applyFilters(Map layerMap) {
	// Apply filters to layer
	layer.filters.clear();
	ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
	for (String filter in layerMap['filters'].keys) {
		if (filter == 'tintColor') {
			int color = layerMap['filters']['tintColor'];
			int amount = layerMap['filters']['tintAmount'];
			if (color != 0 && amount != null && amount != 0) {
				int hexColor = int.parse(amount.toRadixString(16) + color.toRadixString(16), radix:16);
				layerFilter.adjustColoration(hexColor, amount / 90);
			}
		}
		if (filter == 'brightness') {
			layerFilter.adjustBrightness(layerMap['filters']['brightness']/255);
		}
		if (filter == 'saturation') {
			layerFilter.adjustSaturation(layerMap['filters']['saturation']/255);
		}
		if (filter == 'contrast') {
			layerFilter.adjustContrast(layerMap['filters']['contrast']/255);
		}
		if (filter == 'blur') {
			layer.filters.add(new BlurFilter(layerMap['filters']['blur']));
		}
	}
	layer.filters.add(layerFilter);
}

List _decoPool = [];

class Deco extends Bitmap {
	Deco._();

	factory Deco(Map def) {
		Deco deco;
		if (_decoPool.isNotEmpty)
			deco = _decoPool.take(1).single;
		else
			deco = new Deco._();

		deco.bitmapData = RESOURCES.getBitmapData(def['filename']);

		deco.pivotX = deco.width / 2;
		deco.pivotY = deco.height;
		deco.x = def['x'];
		deco.y = def['y'];

		// Set width
		if (def['h_flip'] == true)
			deco.width = -def['w'];
		else
			deco.width = def['w'];
		// Set height
		if (def['v_flip'] == true)
			deco.height = -def['h'];
		else
			deco.height = def['h'];

		if (def['r'] != null) {
			deco.rotation = def['r'] * Math.PI / 180;
		}

		return deco;
	}

	dispose() {
		bitmapData.renderTexture.dispose();
		_decoPool.add(this);
		if (parent != null) {
			parent.removeChild(this);
		}
	}
}
