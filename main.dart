import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LecturePageData {
  String path;
  String text;
  LecturePageData({required this.path, this.text = ''});
  Map<String,dynamic> toJson()=>{'path':path,'text':text};
  factory LecturePageData.fromJson(Map<String,dynamic> j)=>LecturePageData(path:j['path']??'',text:j['text']??'');
}

class Lecture {
  String id,title,date,professor,room,notes,summary;
  List<LecturePageData> pages;
  Lecture({required this.id,required this.title,this.date='',this.professor='',this.room='',this.notes='',this.summary='',List<LecturePageData>? pages}):pages=pages??[];
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'date':date,'professor':professor,'room':room,'notes':notes,'summary':summary,'pages':pages.map((x)=>x.toJson()).toList()};
  factory Lecture.fromJson(Map<String,dynamic> j)=>Lecture(id:j['id']??DateTime.now().microsecondsSinceEpoch.toString(),title:j['title']??'',date:j['date']??'',professor:j['professor']??'',room:j['room']??'',notes:j['notes']??'',summary:j['summary']??'',pages:(j['pages'] as List? ?? []).map((x)=>LecturePageData.fromJson(Map<String,dynamic>.from(x))).toList());
}

class LecturePreparation {
  String id,title,date,priorKnowledge,goals,questions,notes;
  bool completed;
  LecturePreparation({required this.id,required this.title,this.date='',this.priorKnowledge='',this.goals='',this.questions='',this.notes='',this.completed=false});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'date':date,'priorKnowledge':priorKnowledge,'goals':goals,'questions':questions,'notes':notes,'completed':completed};
  factory LecturePreparation.fromJson(Map<String,dynamic> j)=>LecturePreparation(id:j['id']??DateTime.now().microsecondsSinceEpoch.toString(),title:j['title']??'',date:j['date']??'',priorKnowledge:j['priorKnowledge']??'',goals:j['goals']??'',questions:j['questions']??'',notes:j['notes']??'',completed:j['completed']??false);
}

class Course {
  String id,name,code,teacher;
  List<Lecture> lectures;
  List<LecturePreparation> preparations;
  Course({required this.id,required this.name,this.code='',this.teacher='',List<Lecture>? lectures,List<LecturePreparation>? preparations}):lectures=lectures??[],preparations=preparations??[];
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'code':code,'teacher':teacher,'lectures':lectures.map((x)=>x.toJson()).toList(),'preparations':preparations.map((x)=>x.toJson()).toList()};
  factory Course.fromJson(Map<String,dynamic> j)=>Course(id:j['id']??DateTime.now().microsecondsSinceEpoch.toString(),name:j['name']??'',code:j['code']??'',teacher:j['teacher']??'',lectures:(j['lectures'] as List? ?? []).map((x)=>Lecture.fromJson(Map<String,dynamic>.from(x))).toList(),preparations:(j['preparations'] as List? ?? []).map((x)=>LecturePreparation.fromJson(Map<String,dynamic>.from(x))).toList());
}

class AppStore {
  static const key='mahaderati_courses_v1';
  static Future<List<Course>> load() async { final p=await SharedPreferences.getInstance(); final raw=p.getString(key); if(raw==null)return []; return (jsonDecode(raw) as List).map((x)=>Course.fromJson(Map<String,dynamic>.from(x))).toList(); }
  static Future<void> save(List<Course> x) async { final p=await SharedPreferences.getInstance(); await p.setString(key,jsonEncode(x.map((e)=>e.toJson()).toList())); }
}

class MediaStore {
  static Future<Directory> dir() async { final b=await getApplicationDocumentsDirectory(); final d=Directory('${b.path}/mahaderati_pages'); if(!await d.exists())await d.create(recursive:true); return d; }
  static Future<String> copy(String src) async { final f=File(src); if(!await f.exists())throw Exception('الملف غير موجود'); final d=await dir(); final ext=src.toLowerCase().split('.').last; final e=['jpg','jpeg','png','webp'].contains(ext)?ext:'jpg'; final target=File('${d.path}/page_${DateTime.now().microsecondsSinceEpoch}.$e'); await f.copy(target.path); return target.path; }
}

class OcrService {
  static Future<String> read(String path,String lang) async {
    final dir=await FlutterTesseractOcr.getTessdataPath();
    for(final l in lang.split('+')) { final f=File('$dir/$l.traineddata'); if(await f.exists()&&await f.length()>100000)continue; final r=await http.get(Uri.parse('https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/$l.traineddata')); if(r.statusCode!=200)throw Exception('تعذر تنزيل حزمة OCR للغة $l'); await f.writeAsBytes(r.bodyBytes); }
    return FlutterTesseractOcr.extractText(path,language:lang,args:{'psm':'3','preserve_interword_spaces':'1'});
  }
}

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); runApp(const MahaderatiApp()); }

class MahaderatiApp extends StatelessWidget {
  const MahaderatiApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'محاضراتي',theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo,brightness:Brightness.light,inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder())),home:const HomePage());
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  List<Course> courses=[]; bool loading=true; String search='';
  @override void initState(){super.initState();load();}
  Future<void> load() async { courses=await AppStore.load(); if(mounted)setState(()=>loading=false); }
  Future<void> addCourse() async {
    final name=TextEditingController(),code=TextEditingController(),teacher=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('➕ مادة جديدة'),content:SingleChildScrollView(child:Column(children:[TextField(controller:name,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'اسم المادة')),const SizedBox(height:10),TextField(controller:code,textDirection:TextDirection.ltr,decoration:const InputDecoration(labelText:'رمز المادة (اختياري)')),const SizedBox(height:10),TextField(controller:teacher,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'اسم الأستاذ (اختياري'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,name.text.trim().isNotEmpty),child:const Text('إضافة'))]));
    if(ok==true){courses.insert(0,Course(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text.trim(),code:code.text.trim(),teacher:teacher.text.trim()));await AppStore.save(courses);if(mounted)setState((){});} name.dispose();code.dispose();teacher.dispose();
  }
  Future<void> editCourse(Course c) async { final name=TextEditingController(text:c.name),code=TextEditingController(text:c.code),teacher=TextEditingController(text:c.teacher); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('تعديل المادة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'اسم المادة')),TextField(controller:code,decoration:const InputDecoration(labelText:'رمز المادة')),TextField(controller:teacher,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'الأستاذ'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,name.text.trim().isNotEmpty),child:const Text('حفظ'))])); if(ok==true){c.name=name.text.trim();c.code=code.text.trim();c.teacher=teacher.text.trim();await AppStore.save(courses);setState((){});} name.dispose();code.dispose();teacher.dispose(); }
  Future<void> deleteCourse(Course c) async { final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('حذف المادة؟'),content:Text('سيتم حذف المادة «${c.name}» ومحاضراتها من هذا الجهاز.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حذف'))])); if(ok==true){courses.remove(c);await AppStore.save(courses);setState((){});} }
  @override Widget build(BuildContext context){ final q=search.trim().toLowerCase(); final shown=courses.where((c)=>q.isEmpty||c.name.toLowerCase().contains(q)||c.code.toLowerCase().contains(q)||c.lectures.any((l)=>l.title.toLowerCase().contains(q))).toList(); return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('🎓 محاضراتي',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:addCourse,icon:const Icon(Icons.add_circle_outline),tooltip:'إضافة مادة')]),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('دفترك الجامعي الشخصي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('نظّم موادك ومحاضراتك وصور السبورة وملاحظاتك في مكان واحد. هذا التطبيق مستقل للطالب الجامعي.'),const SizedBox(height:14),TextField(textDirection:TextDirection.rtl,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'ابحث في المواد والمحاضرات'),onChanged:(v)=>setState(()=>search=v))])),const SizedBox(height:14),if(shown.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Text('لا توجد مواد بعد.',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:8),FilledButton.icon(onPressed:addCourse,icon:const Icon(Icons.add),label:const Text('إضافة أول مادة'))]))) else ...shown.map((c)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(radius:26,child:Text(c.name.isEmpty?'م':c.name.characters.first)),title:Text(c.name,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),subtitle:Text('${c.code.isEmpty?'':c.code+' • '}${c.teacher.isEmpty?'':c.teacher+' • '}${c.lectures.length} محاضرة'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CoursePage(course:c,all:courses))).then((_){AppStore.load().then((v){if(mounted)setState(()=>courses=v);});}),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')editCourse(c);else deleteCourse(c);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل المادة')),PopupMenuItem(value:'delete',child:Text('حذف المادة'))])))),const SizedBox(height:12),Center(child:Text('المرحلة الأولى: محاضراتي',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))) ]),floatingActionButton:FloatingActionButton.extended(onPressed:addCourse,icon:const Icon(Icons.add),label:const Text('مادة جديدة'))); }
}

class CoursePage extends StatefulWidget { final Course course; final List<Course> all; const CoursePage({super.key,required this.course,required this.all}); @override State<CoursePage> createState()=>_CoursePageState(); }
class _CoursePageState extends State<CoursePage>{ String q='';
  Future<void> addLecture() async { final title=TextEditingController(),prof=TextEditingController(text:widget.course.teacher),room=TextEditingController(),date=TextEditingController(); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('🎙️ محاضرة جديدة'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,autofocus:true,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'عنوان المحاضرة')),TextField(controller:date,decoration:const InputDecoration(labelText:'التاريخ (اختياري)',hintText:'23/09/2026')),TextField(controller:prof,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'الأستاذ')),TextField(controller:room,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'القاعة'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,title.text.trim().isNotEmpty),child:const Text('إنشاء'))])); if(ok==true){final l=Lecture(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),date:date.text.trim(),professor:prof.text.trim(),room:room.text.trim());widget.course.lectures.insert(0,l);await AppStore.save(widget.all);if(mounted){setState((){});Navigator.push(context,MaterialPageRoute(builder:(_)=>LecturePageView(lecture:l,course:widget.course,all:widget.all)));}} title.dispose();prof.dispose();room.dispose();date.dispose(); }
  Future<void> deleteLecture(Lecture l) async { final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('حذف المحاضرة؟'),content:Text('سيتم حذف «${l.title}».'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حذف'))])); if(ok==true){widget.course.lectures.remove(l);await AppStore.save(widget.all);setState((){});} }
  @override Widget build(BuildContext context){final shown=widget.course.lectures.where((l)=>q.isEmpty||l.title.toLowerCase().contains(q.toLowerCase())||l.notes.toLowerCase().contains(q.toLowerCase())||l.summary.toLowerCase().contains(q.toLowerCase())).toList();return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text('📘 ${widget.course.name}'),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PreparationPage(course:widget.course,all:widget.all))).then((_){if(mounted)setState((){});}),icon:const Icon(Icons.event_note_outlined),tooltip:'حضّر محاضرتي'),IconButton(onPressed:addLecture,icon:const Icon(Icons.add),tooltip:'إضافة محاضرة')]),body:ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(widget.course.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),if(widget.course.code.isNotEmpty)Text(widget.course.code),if(widget.course.teacher.isNotEmpty)Text('الأستاذ: ${widget.course.teacher}'),const SizedBox(height:10),TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'ابحث في محاضرات المادة')),const SizedBox(height:10),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PreparationPage(course:widget.course,all:widget.all))).then((_){if(mounted)setState((){});}),icon:const Icon(Icons.event_note),label:Text('📚 حضّر محاضرتي (${widget.course.preparations.length})'))])),const SizedBox(height:10),if(shown.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:Text('لا توجد محاضرات بعد.')))),...shown.map((l)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(14),leading:const Icon(Icons.menu_book_outlined,size:32),title:Text(l.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text([if(l.date.isNotEmpty)l.date,if(l.professor.isNotEmpty)'أستاذ: ${l.professor}',if(l.room.isNotEmpty)'قاعة: ${l.room}','${l.pages.length} صفحة'].join(' • ')),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LecturePageView(lecture:l,course:widget.course,all:widget.all))).then((_){if(mounted)setState((){});}),trailing:IconButton(onPressed:()=>deleteLecture(l),icon:const Icon(Icons.delete_outline))))]),floatingActionButton:FloatingActionButton.extended(onPressed:addLecture,icon:const Icon(Icons.add),label:const Text('محاضرة جديدة')));}
}

class PreparationPage extends StatefulWidget {
  final Course course;
  final List<Course> all;
  const PreparationPage({super.key,required this.course,required this.all});
  @override State<PreparationPage> createState()=>_PreparationPageState();
}

class _PreparationPageState extends State<PreparationPage> {
  Future<void> editPreparation([LecturePreparation? existing]) async {
    final title=TextEditingController(text:existing?.title??'');
    final date=TextEditingController(text:existing?.date??'');
    final prior=TextEditingController(text:existing?.priorKnowledge??'');
    final goals=TextEditingController(text:existing?.goals??'');
    final questions=TextEditingController(text:existing?.questions??'');
    final notes=TextEditingController(text:existing?.notes??'');
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:Text(existing==null?'📚 تحضير محاضرة قادمة':'تعديل التحضير'),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[TextField(controller:title,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'عنوان المحاضرة القادمة *')),const SizedBox(height:10),TextField(controller:date,decoration:const InputDecoration(labelText:'تاريخ المحاضرة (اختياري)')),const SizedBox(height:10),TextField(controller:prior,maxLines:4,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ماذا أعرف مسبقًا؟')),const SizedBox(height:10),TextField(controller:goals,maxLines:4,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ما الذي أريد أن أفهمه؟')),const SizedBox(height:10),TextField(controller:questions,maxLines:4,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'أسئلة أريد طرحها على الأستاذ')),const SizedBox(height:10),TextField(controller:notes,maxLines:4,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ملاحظات'))])),),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,title.text.trim().isNotEmpty),child:const Text('حفظ'))]));
    if(ok==true){
      final item=existing??LecturePreparation(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim());
      item.title=title.text.trim(); item.date=date.text.trim(); item.priorKnowledge=prior.text.trim(); item.goals=goals.text.trim(); item.questions=questions.text.trim(); item.notes=notes.text.trim();
      if(existing==null) widget.course.preparations.insert(0,item);
      await AppStore.save(widget.all); if(mounted)setState((){});
    }
    for(final c in [title,date,prior,goals,questions,notes]) c.dispose();
  }

  List<String> suggestions(String title){
    final t=title.trim();
    if(t.isEmpty)return ['اكتب عنوان المحاضرة أولًا.'];
    return ['اقرأ عنوان المحاضرة وحاول توقع موضوعها.','راجع المفاهيم السابقة المرتبطة بـ «$t».','دوّن 2 أو 3 أسئلة تريد معرفة جوابها أثناء المحاضرة.','بعد المحاضرة، عد إلى هذا التحضير وأكمل ما تعلمته.'];
  }

  @override Widget build(BuildContext context){
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('📚 حضّر محاضرتي')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('حضّر محاضرتك القادمة',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('اكتب عنوان المحاضرة القادمة، وسيساعدك التطبيق بخطوات بسيطة على الاستعداد لها قبل حضورها في القسم.'),const SizedBox(height:14),FilledButton.icon(onPressed:()=>editPreparation(),icon:const Icon(Icons.add),label:const Text('إضافة محاضرة قادمة'))])),
      const SizedBox(height:14),
      if(widget.course.preparations.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد محاضرات قادمة محضّرة بعد.')))
      else ...widget.course.preparations.map((p)=>Card(child:ExpansionTile(title:Text(p.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(p.completed?'✓ تمت متابعة المحاضرة':'لم تُستكمل بعد'),leading:Icon(p.completed?Icons.check_circle:Icons.event_note),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(p.date.isNotEmpty)Text('📅 ${p.date}'),if(p.priorKnowledge.isNotEmpty)...[const SizedBox(height:8),const Text('ماذا أعرف مسبقًا؟',style:TextStyle(fontWeight:FontWeight.bold)),Text(p.priorKnowledge)],if(p.goals.isNotEmpty)...[const SizedBox(height:8),const Text('ما الذي أريد أن أفهمه؟',style:TextStyle(fontWeight:FontWeight.bold)),Text(p.goals)],if(p.questions.isNotEmpty)...[const SizedBox(height:8),const Text('أسئلتي للأستاذ',style:TextStyle(fontWeight:FontWeight.bold)),Text(p.questions)],if(p.notes.isNotEmpty)...[const SizedBox(height:8),const Text('ملاحظاتي',style:TextStyle(fontWeight:FontWeight.bold)),Text(p.notes)],const SizedBox(height:12),const Text('💡 خطوات مقترحة',style:TextStyle(fontWeight:FontWeight.bold)),...suggestions(p.title).map((x)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.lightbulb_outline),title:Text(x))),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>editPreparation(p),icon:const Icon(Icons.edit),label:const Text('تعديل'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:() async {p.completed=!p.completed;await AppStore.save(widget.all);setState((){});},icon:Icon(p.completed?Icons.undo:Icons.check),label:Text(p.completed?'إلغاء الاكتمال':'أكملت المحاضرة'))),const SizedBox(width:8),IconButton(onPressed:() async {widget.course.preparations.remove(p);await AppStore.save(widget.all);setState((){});},icon:const Icon(Icons.delete_outline))])]))]))
    ]),floatingActionButton:FloatingActionButton.extended(onPressed:()=>editPreparation(),icon:const Icon(Icons.add),label:const Text('تحضير جديد')));
  }
}

class LecturePageView extends StatefulWidget { final Lecture lecture; final Course course; final List<Course> all; const LecturePageView({super.key,required this.lecture,required this.course,required this.all}); @override State<LecturePageView> createState()=>_LecturePageViewState(); }
class _LecturePageViewState extends State<LecturePageView>{ bool busy=false; String lang='ara+fra'; final picker=ImagePicker();
  Future<void> addImage(ImageSource source) async { final x=await picker.pickImage(source:source,imageQuality:92); if(x==null)return; final p=await MediaStore.copy(x.path); widget.lecture.pages.add(LecturePageData(path:p)); await AppStore.save(widget.all);setState((){}); }
  Future<void> ocrPage(LecturePageData p) async {setState(()=>busy=true);try{p.text=await OcrService.read(p.path,lang);await AppStore.save(widget.all);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم استخراج النص من الصفحة.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر استخراج النص: $e')));}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> editNotes() async {final c=TextEditingController(text:widget.lecture.notes),s=TextEditingController(text:widget.lecture.summary);final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('📝 ملاحظات المحاضرة'),content:SingleChildScrollView(child:Column(children:[TextField(controller:c,maxLines:8,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ملاحظاتي')),TextField(controller:s,maxLines:8,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ملخص المحاضرة'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حفظ'))]));if(ok==true){widget.lecture.notes=c.text.trim();widget.lecture.summary=s.text.trim();await AppStore.save(widget.all);setState((){});}c.dispose();s.dispose();}
  Future<pw.Font?> font() async {try{final d=await getApplicationDocumentsDirectory();final f=File('${d.path}/DejaVuSans.ttf');if(!await f.exists()){final r=await http.get(Uri.parse('https://github.com/dejavu-fonts/dejavu/raw/master/ttf/DejaVuSans.ttf'));if(r.statusCode!=200)return null;await f.writeAsBytes(r.bodyBytes);}return pw.Font.ttf((await f.readAsBytes()).buffer.asByteData());}catch(_){return null;}}
  Future<void> exportPdf() async {final doc=pw.Document();final f=await font();for(var i=0;i<widget.lecture.pages.length;i++){final p=widget.lecture.pages[i],file=File(p.path);if(!await file.exists())continue;final b=await file.readAsBytes();doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(16),build:(_)=>pw.Column(children:[pw.Text(widget.lecture.title,style:pw.TextStyle(font:f,fontSize:15)),pw.SizedBox(height:8),pw.Expanded(child:pw.Image(pw.MemoryImage(b),fit:pw.BoxFit.contain)),if(p.text.trim().isNotEmpty)pw.Padding(padding:const pw.EdgeInsets.only(top:8),child:pw.Text(p.text,textDirection:pw.TextDirection.rtl,style:pw.TextStyle(font:f,fontSize:9))) ])));}if(widget.lecture.notes.trim().isNotEmpty){doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,build:(_)=>pw.Padding(padding:const pw.EdgeInsets.all(24),child:pw.Text(widget.lecture.notes,textDirection:pw.TextDirection.rtl,style:pw.TextStyle(font:f,fontSize:14)))));}await Printing.sharePdf(bytes:await doc.save(),filename:'${widget.lecture.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF -]'),'_')}.pdf');}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(widget.lecture.title),actions:[IconButton(onPressed:editNotes,icon:const Icon(Icons.edit_note),tooltip:'الملاحظات'),IconButton(onPressed:exportPdf,icon:const Icon(Icons.picture_as_pdf_outlined),tooltip:'PDF')]),body:busy?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(14),children:[Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(widget.lecture.title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),if(widget.lecture.date.isNotEmpty)Text('📅 ${widget.lecture.date}'),if(widget.lecture.professor.isNotEmpty)Text('👨‍🏫 ${widget.lecture.professor}'),if(widget.lecture.room.isNotEmpty)Text('🏫 ${widget.lecture.room}'),const SizedBox(height:10),Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>addImage(ImageSource.camera),icon:const Icon(Icons.camera_alt),label:const Text('تصوير السبورة'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>addImage(ImageSource.gallery),icon:const Icon(Icons.photo_library),label:const Text('من الهاتف')))]),const SizedBox(height:8),OutlinedButton.icon(onPressed:editNotes,icon:const Icon(Icons.note_alt_outlined),label:const Text('ملاحظاتي وملخصي'))])),if(widget.lecture.pages.isNotEmpty) ...[const SizedBox(height:12),const Text('📄 صفحات المحاضرة',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),...widget.lecture.pages.asMap().entries.map((e)=>Card(child:ExpansionTile(leading:Image.file(File(e.value.path),width:58,height:58,fit:BoxFit.cover),title:Text('الصفحة ${e.key+1}'),subtitle:Text(e.value.text.trim().isEmpty?'لم يُستخرج النص بعد':'تم استخراج النص'),children:[Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[DropdownButton<String>(value:lang,items:const [DropdownMenuItem(value:'ara',child:Text('عربية')),DropdownMenuItem(value:'fra',child:Text('Français')),DropdownMenuItem(value:'eng',child:Text('English')),DropdownMenuItem(value:'ara+fra',child:Text('عربية + فرنسية')),DropdownMenuItem(value:'ara+eng',child:Text('عربية + إنجليزية'))],onChanged:(v)=>setState(()=>lang=v??lang)),const Spacer(),IconButton(onPressed:()=>ocrPage(e.value),icon:const Icon(Icons.text_snippet_outlined),tooltip:'استخراج النص')]),if(e.value.text.trim().isNotEmpty)SelectableText(e.value.text,textDirection:TextDirection.rtl),Align(alignment:Alignment.centerLeft,child:IconButton(onPressed:() async {widget.lecture.pages.removeAt(e.key);await AppStore.save(widget.all);setState((){});},icon:const Icon(Icons.delete_outline))) ])))))],if(widget.lecture.pages.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('ابدأ بتصوير السبورة أو إضافة صور المحاضرة.'))]));
}
