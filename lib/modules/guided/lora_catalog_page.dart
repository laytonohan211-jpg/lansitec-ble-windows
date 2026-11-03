import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lorawan_protocol.dart';
import 'livestock_protocol.dart';

const extraLoRaModels=['UWB Tracker','UWB Anchor','PT100 Sensor','Temperature / Humidity Sensor','Rotary Valve Sensor','Contact Tracing Badge'];
List<LoRaParameter> extraParameters(String model,String operation) {
  if(model.startsWith('UWB')) {
    if(operation=='Heartbeat')return [const LoRaParameter('value','Heartbeat (seconds)','3600',1966050,min:30,step:30)];
    if(operation=='Clock sync interval')return [const LoRaParameter('value','Interval (seconds)','128',512,min:1)];
    if(operation=='Clock sync spreading factor')return [const LoRaParameter('value','Spreading factor','9',12,min:7)];
    if(operation=='Clock sync bandwidth')return [const LoRaParameter('value','0: 500 kHz, 1: 250 kHz, 2: 125 kHz','1',2)];
    if(operation=='Advertising interval')return [const LoRaParameter('value','UWB advertising interval (milliseconds)','8000',4294967295,min:1)];
    if(operation=='Confirm every N heartbeats'||operation=='Missed acknowledgements')return [const LoRaParameter('value','Count','2',255)];
    if(operation=='Fall threshold')return [const LoRaParameter('value','Threshold (units of 0.5 m)','4',255)];
    return [];
  }
  if(model.contains('PT100') || model.startsWith('Temperature'))return operation=='Report interval'?[const LoRaParameter('value','Report interval (seconds)','600',655350,min:10,step:10)]:[];
  return [];
}
List<String> extraOperations(String model)=>[
  if(model.startsWith('UWB'))...['Heartbeat','Confirm every N heartbeats','Missed acknowledgements','Clock sync interval','Clock sync spreading factor','Clock sync bandwidth',if(model=='UWB Anchor')'Advertising interval',if(model=='UWB Tracker')'Fall threshold','Read configuration'],
  if(model.contains('PT100')||model.startsWith('Temperature'))'Report interval',
  'Request registration','Restart',
  if(model=='Contact Tracing Badge')...['Start continuous scanning','Stop continuous scanning'],
  if(model=='UWB Tracker')'Request position',
];
String extraCommand(String model,String operation,Map<String,String> fields,int messageId){
  if (!extraLoRaModels.contains(model)) throw const FormatException('Unknown device');
  final params=extraParameters(model,operation),n=<String,int>{};
  for(final p in params){final v=int.tryParse(fields[p.key]??'');if(v==null || v<p.min || v>p.max || v%p.step!=0)throw FormatException('${p.label}: ${p.min}–${p.max}, step ${p.step}');n[p.key]=v~/p.step;}
  String hex(int x,int width)=>x.toRadixString(16).padLeft(width*2,'0').toUpperCase();
  if(messageId<1 || messageId>65535)throw const FormatException('Message ID: 1–65535');
  if(model.startsWith('UWB')){
    const ids={'Heartbeat':1,'Confirm every N heartbeats':50,'Missed acknowledgements':51,'Clock sync interval':82,'Clock sync spreading factor':84,'Clock sync bandwidth':85,'Advertising interval':94,'Fall threshold':8};
    if(operation=='Read configuration')return 'B000${hex(messageId,2)}';
    if(ids.containsKey(operation)){final id=ids[operation]!,w=[1,82].contains(id)?2:id==94?4:1;return 'A0${hex(id,1)}${hex(n['value']!,w)}${hex(messageId,2)}';}
    return 'C0${hex(operation=='Request position'?1:operation=='Restart'?3:2,1)}${hex(messageId,2)}';
  }
  if(model.contains('PT100')||model.startsWith('Temperature')){
    if(operation=='Report interval')return '90${hex(n['value']!,2)}';
    if(messageId>255)throw const FormatException('Message ID: 1–255');
    return '${operation=='Restart'?'A2':'A1'}${hex(messageId,1)}';
  }
  if(model=='Contact Tracing Badge'){
    if(messageId>255)throw const FormatException('Message ID: 1–255');
    final id=operation=='Restart'?3:operation=='Start continuous scanning'?5:operation=='Stop continuous scanning'?4:2;
    return 'A${hex(id,1).substring(1)}${hex(messageId,1)}00';
  }
  return operation=='Restart'?'A300':operation=='Request position'?'A100':'A200';
}

class LoRaCommandPage extends StatefulWidget {
  final LoRaModel? model;final String? extra;
  const LoRaCommandPage({super.key,this.model,this.extra});
  @override State<LoRaCommandPage> createState()=>_LoRaCommandPageState();
}
class _LoRaCommandPageState extends State<LoRaCommandPage>{
  final editors=<String,TextEditingController>{};
  final message=TextEditingController(text:'1');
  String operation='',result='';
  List<String> get operations=>widget.extra!=null?extraOperations(widget.extra!):['Tracking configuration','Request registration','Restart',if(widget.model!=LoRaModel.gateway)'Request position',if(widget.model==LoRaModel.gateway)...['Start continuous scanning','Stop continuous scanning','Request filter rules'],if(widget.model==LoRaModel.helmet)...['Wear calibration','Beep','Request beacon UUIDs']];
  List<LoRaParameter> get params=>widget.extra!=null?extraParameters(widget.extra!,operation):operation=='Tracking configuration'?loRaParameters(widget.model!):[];
  void select(String op){for(final c in editors.values){c.dispose();}editors.clear();operation=op;for(final p in params){editors[p.key]=TextEditingController(text:p.preset);}if(widget.model==LoRaModel.container && op=='Tracking configuration')editors['uuid']=TextEditingController(text:'F2A52D43E0AB489CB64C4A8300146720');result='';}
  @override void initState(){super.initState();select(operations.first);}
  @override void dispose(){for(final c in editors.values){c.dispose();}message.dispose();super.dispose();}
  void generate(){try{
    final fields={for(final e in editors.entries)e.key:e.value.text};
    if(widget.extra!=null){result=extraCommand(widget.extra!,operation,fields,int.tryParse(message.text)??0);}
    else if(operation=='Tracking configuration'){result=loRaSettings(widget.model!,fields);}
    else{
      final id={'Request registration':2,'Restart':3,'Request position':1,'Start continuous scanning':5,'Stop continuous scanning':4,'Request filter rules':8,'Wear calibration':4,'Beep':5,'Request beacon UUIDs':6}[operation]!;
      result='A${id.toRadixString(16)}00${widget.model==LoRaModel.gateway?'00':''}'.toUpperCase();
    }
  }catch(e){result=e is FormatException?e.message:'$e';}setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.extra??loRaModelLabel(widget.model!))),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Create a LoRaWAN downlink'),const SizedBox(height:12),
    DropdownButtonFormField<String>(value:operation,isExpanded:true,items:[for(final op in operations)DropdownMenuItem(value:op,child:Text(op))],onChanged:(v){if(v!=null)setState(()=>select(v));}),
    if(widget.extra!=null && (widget.extra!.startsWith('UWB')||widget.extra!.contains('Sensor')||widget.extra=='Contact Tracing Badge'))TextField(controller:message,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Message ID')),
    for(final p in params)Padding(padding:const EdgeInsets.only(top:16),child:TextField(controller:editors[p.key],keyboardType:TextInputType.number,decoration:InputDecoration(labelText:p.label))),
    if(editors.containsKey('uuid'))TextField(controller:editors['uuid'],decoration:const InputDecoration(labelText:'Positioning UUID')),
    const SizedBox(height:20),FilledButton(onPressed:generate,child:const Text('Create command')),
    if(result.isNotEmpty)...[SelectableText(result),if(RegExp(r'^[0-9A-F]+$').hasMatch(result))TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:result));},icon:const Icon(Icons.copy),label:const Text('Copy downlink'))],
  ]));
}
