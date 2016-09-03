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

	for (Map layerMap in street['dynamic']['layers'].values) {
		// Sort decos by z value
		List decoList = new List.from(layerMap['decos'])
			..sort((Map A, Map B) => A['z'].compareTo(B['z']));

		//load the bitmaps
		int timestamp = new DateTime.now().millisecondsSinceEpoch;
		for (Map decoMap in decoList) {
			String resourceName = '${decoMap['filename']}_${decoMap['w']}_${decoMap['h']}';
			if (!RESOURCES.containsBitmapData(resourceName)) {
				String url = 'http://cou.robertmcdermot.com/get_sized_image.php';
				url += '?filename=${decoMap['filename']}&width=${decoMap['w']}&height=${decoMap['h']}&time=$timestamp';
				RESOURCES.addBitmapData(resourceName, url, loadOptions);
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

			String resourceName = '${decoMap['filename']}_${decoMap['w']}_${decoMap['h']}';
			if (!RESOURCES.containsBitmapData(resourceName) ||
			    failedNames.contains(resourceName)) {
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
		layer.removeChildren();
		results['layers'][layerMap['name']] = dataUrl;
	}

	return results;
}

void applyFilters(Map layerMap) {
	// Apply filters to layer
	layer.filters.clear();
	for (String filter in layerMap['filters'].keys) {
		if (filter == 'contrast') {
			ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
			layerFilter.adjustContrast(layerMap['filters']['contrast']/100);
			layer.filters.add(layerFilter);
		}
		if (filter == 'saturation') {
			ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
			layerFilter.adjustSaturation(layerMap['filters']['saturation']/100);
			layer.filters.add(layerFilter);
		}
		if (filter == 'tintColor') {
			int color = layerMap['filters']['tintColor'];
			int amount = layerMap['filters']['tintAmount'];
			if (color != 0 && amount != null && amount != 0) {
//				int hexColor = int.parse(color.toRadixString(16), radix:16);
				ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
				layerFilter.adjustColoration(layerMap['filters']['tintColor'], amount / 100);
				layer.filters.add(layerFilter);
			}
		}

		if (filter == 'brightness') {
			ColorMatrixFilter layerFilter = new ColorMatrixFilter.identity();
			layerFilter.adjustBrightness(layerMap['filters']['brightness']/255);
			layer.filters.add(layerFilter);
		}

		if (filter == 'blur') {
			layer.filters.add(new BlurFilter(layerMap['filters']['blur'], layerMap['filters']['blur']));
		}
	}
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

		String resourceName = '${def['filename']}_${def['w']}_${def['h']}';
		deco.bitmapData = RESOURCES.getBitmapData(resourceName);

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
