library main;

import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'package:prerender/prerender.dart';
import 'package:stagexl/stagexl.dart';

part 'finished.dart';
part 'todo.dart';

main() async {
    StageXL.stageOptions
        ..transparent = true
        ..backgroundColor = 0x00000000;
    new RenderLoop()
        ..addStage(STAGE);

    await parseStreets();

    print('done!');
}

int i = 0;

Future parseStreets() async {
    if (streetsToParse.length == 2 && window.localStorage['toParse'] != null) {
        streetsToParse = JSON.decode(window.localStorage['toParse']);
    }

    if (streetsParsed.isEmpty && window.localStorage['parsed'] != null) {
        streetsParsed = JSON.decode(window.localStorage['parsed']);
    }


//    hell
//    List<String> streetsToParse = ['LA5PV4T79OE2AOA'];
//    jantik joj
//    List<String> streetsToParse = ['LA517MT2M262D0F'];
//    jal
//    List<String> streetsToParse = ['LUV270LMU8A3UCB'];

    while (streetsToParse.isNotEmpty) {
        String currentTsid = streetsToParse.removeLast();
        Map street = await getStreet(currentTsid);
        String currentLabel = street['label'];
        print('parsing $currentLabel');

        Map response = await prerender(street);

//		print(response.toString());
        //now upload renderedStreet
        await HttpRequest.request('http://localhost:8181/uploadStreetRender', method: "POST",
                                      requestHeaders: {"content-type": "application/json"},
                                      sendData: JSON.encode(response));

        streetsParsed.add(currentTsid);
        window.localStorage['parsed'] = JSON.encode(streetsParsed);
        window.localStorage['toParse'] = JSON.encode(streetsToParse);
        i++;

        List<Map> signposts = street['dynamic']['layers']['middleground']['signposts'];
        signposts.forEach((Map signpost) {
            List<Map> connects = signpost['connects'];
            connects.forEach((Map connection) {
                String tsid = connection['tsid'];
                String label = connection['label'];
                if (!streetsParsed.contains(tsid)) {
                    streetsToParse.add(tsid);
                    print('queuing up $label');
                }
            });
        });

        if (i >= 25)
            window.location.reload();
    }
}

Future<Map> getStreet(String tsid) async {
    if (tsid.startsWith('L')) {
        tsid = tsid.replaceFirst('L', 'G');
    }
    String url = "http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$tsid.json";
    String response = await HttpRequest.getString(url);

    Map street = JSON.decode(response);
    return street;
}