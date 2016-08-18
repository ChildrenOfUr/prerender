library main;

import 'dart:html';
import 'dart:math' as Math;
import 'dart:async';
import 'dart:convert';
import 'package:prerender/prerender.dart';
import 'package:prerender/API_KEYS.dart';
import 'package:stagexl/stagexl.dart' hide KeyboardEvent;

class Camera {
	bool dirty = true;
	int _x = 0, _y = 0, _previousX = 0, _previousY = 0;
	Math.Rectangle bounds;

	Camera(this.bounds);

	int get x => _x;
	int get y => _y;

	void set x(int newX) {
		_previousX = _x;
		if (newX < 0) {
			newX = 0;
		}
		if (newX > bounds.width - layersWidth) {
			newX = bounds.width - layersWidth;
		}

		_x = newX;

		if (_x != _previousX) {
			dirty = true;
		}
	}

	void set y(int newY) {
		_previousY = _y;
		if (newY < 0) {
			newY = 0;
		}
		if (newY > bounds.height - layersHeight) {
			newY = bounds.height - layersHeight;
		}

		_y = newY;

		if (_y != _previousY) {
			dirty = true;
		}
	}
}

List<String> streetsParsed = [];
bool upKey = false, downKey = false, leftKey = false, rightKey = false;
DivElement layers = querySelector('#LayerWindow');
int cameraX = 0, cameraY = 0, layersWidth, layersHeight;
Math.Rectangle bounds;
Camera camera;

main() async {
	StageXL.stageOptions
		..transparent = true
		..backgroundColor = 0x00000000;
	new RenderLoop()
		..addStage(STAGE);

	ButtonElement doIt = querySelector("#DoIt");
	doIt.onClick.listen((_) async {
		TextAreaElement streetList = querySelector("#StreetList");
		List<String> streets = streetList.value.split('\n');
		streets.removeWhere((String street) => street.isEmpty);
		print('$streets : ${streets.length}');
		parseStreets(streets);
	});

	resize();
	window.onResize.listen((_) => resize());

	window.onKeyDown.listen((KeyboardEvent k) {
		//up
		if (k.keyCode == 87 || k.keyCode ==  38) {
			upKey = true;
		}
		//down
		if (k.keyCode == 83 || k.keyCode ==  40) {
			downKey = true;
		}
		//left
		if (k.keyCode == 65 || k.keyCode ==  37) {
			leftKey = true;
		}
		//right
		if (k.keyCode == 68 || k.keyCode ==  39) {
			rightKey = true;
		}
	});
	window.onKeyUp.listen((KeyboardEvent k) {
		//up
		if (k.keyCode == 87 || k.keyCode ==  38) {
			upKey = false;
		}
		//down
		if (k.keyCode == 83 || k.keyCode ==  40) {
			downKey = false;
		}
		//left
		if (k.keyCode == 65 || k.keyCode ==  37) {
			leftKey = false;
		}
		//right
		if (k.keyCode == 68 || k.keyCode ==  39) {
			rightKey = false;
		}
	});
}

resize() {
	int topHeight = querySelector('#TopBit').clientHeight;
	int remaining = window.innerHeight - topHeight - 25;
	layers.style.height = '${remaining}px';
	layersWidth = layers.clientWidth;
	layersHeight = layers.clientHeight;
}

Future parseStreets(List<String> streetsToParse) async {
//	List<String> streetsToParse = ['GM11E7ODKHO1QJE'];

	await Future.doWhile(() async {
		String currentTsid = streetsToParse.removeLast();
		if (currentTsid.startsWith('L')) {
			currentTsid = currentTsid.replaceFirst('L', 'G');
		}

		Map street = await getStreet(currentTsid);
		String currentLabel = street['label'];
		querySelector("#CurrentRender").text = 'Rendering: $currentLabel';

		querySelector("#LoadingDialog").hidden = false;

		Map response = await prerender(street);
		response['redstoneToken'] = redstoneToken;

		//now upload renderedStreet
		HttpRequest request = await HttpRequest.request('http://robertmcdermot.com:8181/uploadStreetRender', method: "POST",
			requestHeaders: {"content-type": "application/json"},
			sendData: JSON.encode(response));

		querySelector("#LoadingDialog").hidden = true;

		//Now add the files to the page so we can preview it for QA
		if (await previewStreet(street)) {
			//now transfer the street from the dev folder to the live folder
			String url = 'http://childrenofur.com/assets/make_street_layers_live.php';
			HttpRequest request = await HttpRequest.postFormData(url,
				{'redstoneToken': redstoneToken, 'tsid': currentTsid.replaceFirst('G','L')});
			print(request.responseText);
		}

//		streetsParsed.add(currentTsid);
//		window.localStorage['parsed'] = JSON.encode(streetsParsed);
//		window.localStorage['toParse'] = JSON.encode(streetsToParse);

//		List<Map> signposts = street['dynamic']['layers']['middleground']['signposts'];
//		signposts.forEach((Map signpost) {
//			List<Map> connects = signpost['connects'];
//			connects.forEach((Map connection) {
//				String tsid = connection['tsid'];
//				String label = connection['label'];
//				if (!streetsParsed.contains(tsid)) {
//					streetsToParse.add(tsid);
//					print('queuing up $label');
//				}
//			});
//		});

		return streetsToParse.isNotEmpty;
	});

	(querySelector("#StreetList") as TextAreaElement).value = '';
}

Future<bool> previewStreet(Map street) async {
	Completer c = new Completer();

	bounds = new Math.Rectangle(street['dynamic']['l'],
		street['dynamic']['t'],
		street['dynamic']['l'].abs() + street['dynamic']['r'].abs(),
		(street['dynamic']['t'] - street['dynamic']['b']).abs());

	camera = new Camera(bounds);

	String tsid = street['tsid'].replaceFirst('G', 'L');
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

	for (Map layer in street['dynamic']['layers'].values) {
		String layerName = layer['name'].replaceAll(' ', '_');
		String url = 'http://childrenofur.com/assets/streetLayers/dev/$tsid/$layerName.png';
		ImageElement image = new ImageElement(src:url);
		image.style.position = 'absolute';
		image.style.zIndex = layer['z'].toString();
		image.attributes['currentX'] = '0';
		image.attributes['currentY'] = '0';
		layers.append(image);
	}

	render();

	Element looksGood = querySelector('#LooksGood');
	looksGood.hidden = false;
	querySelector('#YesButton').onClick.first.then((_) {
		looksGood.hidden = true;
		c.complete(true);
	});
	querySelector('#NoButton').onClick.first.then((_) {
		looksGood.hidden = true;
		c.complete(false);
	});

	return c.future;
}

render() async {
	int xdiff = (rightKey ? 15 : 0) + (leftKey ? -15 : 0);
	int ydiff = (upKey ? -15 : 0) + (downKey ? 15 : 0);

	camera.x = camera.x + xdiff;
	camera.y = camera.y + ydiff;

	num camXPercent = camera.x / (bounds.width - layersWidth);
	num camYPercent = camera.y / (bounds.height - layersHeight);

	layers.children.forEach((Element layer) {
		if (layer is ImageElement) {
			num layerOffsetX = camXPercent * (layer.naturalWidth - layersWidth);
			num layerOffsetY = camYPercent * (layer.naturalHeight - layersHeight);

			layer.style.transform = 'translate(-${layerOffsetX}px, -${layerOffsetY}px)';
		}
	});

	await window.animationFrame;
	render();
}

Future<Map> getStreet(String tsid) async {
	String url = 
"https://rawgit.com/ChildrenOfUr/CAT422-glitch-location-viewer/master/locations/$tsid.json";
	String response = await HttpRequest.getString(url);

	Map street = JSON.decode(response);
	return street;
}
