// lib/services/ai_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

class AiService {
  final String apiKey;
  late final GenerativeModel _model;

  AiService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 4096,
      ),
      // --- MODIFIED: REMOVED safetySettings ENTIRELY ---
      // safetySettings: [ ... ] // This whole block is now gone!
      // --- END MODIFICATION ---
    );
  }

  /// Extracts text from a PDF file using Syncfusion PDF.
  Future<String?> extractPdfText(String filePath) async {
    PdfDocument? document;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('AI Service: PDF file not found at $filePath');
        return null;
      }

      final List<int> bytes = await file.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      print("Extracted ${text.length} characters using Syncfusion.");
      return text;

    } catch (e) {
      print('Error extracting PDF text with Syncfusion: $e');
      document?.dispose();
      return null;
    }
  }

  Future<String?> _generateContent(String prompt, String pdfText) async {
    try {
      final fullPrompt = '$prompt\n\n--- PDF Content ---\n$pdfText';
      final response = await _model.generateContent([Content.text(fullPrompt)]);
      return response.text;
    } catch (e) {
      print('Error generating AI content: $e');
      if (e is GenerativeAIException) { return "AI Error: ${e.message}"; }
      return 'Failed to get a response from AI.';
    }
  }

  // UPDATED PROMPT FOR summarizePdf - Removed citation and specific number
  Future<String?> summarizePdf(String pdfText) async {
    const prompt = '''
Create a highly detailed and comprehensive summary of the entire provided document.
The summary should be structured logically, capturing all major concepts, definitions, processes, and conclusions.
Ensure that every piece of factual information, key idea, and argument from the document is included without omission.
The original wording and phrasing from the document must be preserved wherever precision is critical (e.g., for definitions, classifications, or specific causes/effects).
The summary should be suitable for a student needing to grasp all essential information from the text.
''';
    return await _generateContent(prompt, pdfText);
  }

  // UPDATED PROMPT FOR getKeyPoints - Removed citation and specific number
  Future<String?> getKeyPoints(String pdfText) async {
    const prompt = '''
Extract ALL significant main key points from the following text.
These points should represent the most crucial information, central arguments, or core takeaways.
Present them as a concise, numbered list.
Each point should be a complete sentence or two, summarizing a significant aspect of the text.
''';
    return await _generateContent(prompt, pdfText);
  }
  
  // UPDATED PROMPT FOR getImportantTopics - Removed citation and specific number
  Future<String?> getImportantTopics(String pdfText) async {
    const prompt = '''
Identify and list ALL important topics or concepts covered in the text that are critical for a deep understanding. Do not limit the number; include every topic that is significant.
For each topic:
1.  State the topic name in **bold**.
2.  Provide a clear, concise introductory explanation of the topic.
3.  **Crucially, extract MULTIPLE DIRECT QUOTES** (at least 2-3 significant sentences or phrases) from the text that explain the topic in detail, provide examples, definitions, or elaborate on its nuances.
4.  Ensure that ALL critical concepts, formulas, equations, definitions, classifications, mechanisms, and examples related to this topic, as explicitly stated in the text, are captured within the quotes or accompanying brief explanations.
Format as a bulleted list of topics, with sub-bullets for quotes and explanations. This output is for a study guide, so be comprehensive and include everything a student would need to memorize for an exam.
''';
    return await _generateContent(prompt, pdfText);
  }

  // UPDATED PROMPT FOR getKeyTerms - Removed citation and specific number
  Future<String?> getKeyTerms(String pdfText) async {
    const prompt = '''
Extract ALL essential key terms or concepts from the following text that are fundamental to understanding the subject matter. Do not limit the number; include every term that is important.
For each term, provide the following details comprehensively:
1.  The term name in **bold**.
2.  A **detailed, precise definition** that captures all nuances and specific characteristics as described *exactly in the text*. Use original wording from the PDF for definitions wherever possible.
3.  At least **one direct quote** from the text (a full sentence or phrase) that illustrates how the term is used in context, provides an example, or offers further explanation.
4.  Any **related formulas, equations, classifications, processes, specific examples, or numerical values** that are explicitly associated with the term in the text. Describe any relevant diagrams if mentioned.
Format as a clear, numbered list with each term and its associated details presented distinctly. This section is for memorization, so ensure maximum detail and accuracy directly from the source.
''';
    return await _generateContent(prompt, pdfText);
  }

  // UPDATED PROMPT FOR getStudyRoadmap - Removed specific number
  Future<String?> getStudyRoadmap(String pdfText) async {
    const prompt = '''
Create a highly structured and logical study roadmap based on the following text.
Break down the content into distinct, progressive study sessions.
For each session, provide:
1.  A **Session Title** (e.g., "Session 1: Foundational Concepts").
2.  A brief overview of **What to Focus On** in this session, explaining the main topics covered.
3.  An explanation of **How Topics Build Upon Each Other** or the logical progression within or from previous sessions.
4.  A clear, numbered list of **Specific Concepts to Master** before moving to the next session. These should be actionable learning objectives.
5.  Suggest practical **Study Activities** for each session (e.g., "Review definitions," "Practice problem-solving," "Create a diagram").
The roadmap should guide a student through the material in a sequential, effective manner, ensuring foundational knowledge is built before moving to advanced topics.
''';
    return await _generateContent(prompt, pdfText);
  }

  // UPDATED PROMPT FOR getDiscussionQuestions - Removed specific number
  Future<String?> getDiscussionQuestions(String pdfText) async {
    const prompt = '''
Generate thought-provoking and open-ended discussion questions based *solely* on the following text.
These questions should:
1.  Encourage critical thinking, analysis, synthesis of information, and application of concepts from the text.
2.  Go beyond simple recall and require students to interpret, evaluate, or compare information.
3.  Avoid questions with single, factual answers.
4.  Be suitable for a classroom discussion or a reflective essay.
Format as a numbered list.
''';
    return await _generateContent(prompt, pdfText);
  }
  
  Future<Map<String, String>?> generateComprehensiveStudyGuide(String pdfText) async {
    const prompt = '''
Create a comprehensive study guide for the following text. The study guide MUST include all the specified sections below, each clearly labeled with its heading.

**IMPORTANT OVERALL INSTRUCTIONS FOR THE ENTIRE STUDY GUIDE:**
1.  **Strictly adhere to the section titles and their content requirements.**
2.  **Accuracy and Completeness**: Ensure that all information is derived *exclusively* from the provided PDF text. Do not invent, infer, or hallucinate any content.
3.  **Original Wording**: Wherever possible, especially for definitions, formulas, or key explanations, use the *exact original wording* from the PDF text.
4.  **Comprehensiveness**: This study guide is intended for a student to memorize and deeply understand the material. Therefore, be *extremely thorough and detailed* within the constraints of each section.

--- STUDY GUIDE SECTIONS ---

**1. SUMMARY:**
* Provide a detailed, cohesive summary (aim for 300-400 words) of the main content and key themes presented in the entire document.
* Ensure that all major topics and conclusions from the document are captured comprehensively.
* The summary should flow naturally and capture the essence of the document.

**2. IMPORTANT TOPICS:**
* Identify and list ALL important, distinct topics or concepts discussed in the document. Do not limit the number.
* For each topic, provide a brief introductory sentence or phrase defining or explaining it.
* Crucially, for each topic, extract **MULTIPLE DIRECT QUOTES** (at least 2-3 significant sentences or phrases) from the text that explain the topic in detail, provide examples, or elaborate on its nuances.
* Format as a bulleted list. Each topic name should be **bolded**.
* Ensure that ALL critical concepts, formulas, definitions, and examples related to these topics, as present in the text, are captured within the quotes or accompanying explanations.

**3. KEY TERMS:**
* Extract ALL essential key terms or concepts from the document that a student would need to know for an exam. Do not limit the number.
* For each term, provide the following:
    * The term name in **bold**.
    * A **detailed definition** that captures all nuances and specific characteristics as described *in the text*. Use original wording from the PDF for definitions wherever possible.
    * At least **one direct quote** from the text demonstrating how the term is used in context or providing further explanation.
    * Any **related formulas, equations, diagrams (describe if present in text), or numerical examples** that help explain the term, as found in the text.
* Format as a bulleted list, with each term and its details clearly separated.

**4. STUDY ROADMAP:**
* Create a structured study roadmap, breaking down the document's content into distinct, logical study sessions.
* For each session:
    * Suggest what major topics or sections to focus on.
    * Explain how topics build upon each other or why they are grouped together.
    * List specific concepts, terms, or skills that a student should aim to **master before moving to the next session**.
* This roadmap should guide a student through the material in a progressive and effective manner.

**5. DISCUSSION QUESTIONS:**
* Generate thought-provoking, open-ended discussion questions based on the text.
* These questions should encourage critical thinking, analysis, synthesis, or application of the material, going beyond simple recall.
* Format as a numbered list.

**END OF PROMPT**
''';
    
    final result = await _generateContent(prompt, pdfText);
    if (result == null) return null;
    
    // Parse the result into sections
    Map<String, String> sections = {};
    
    // Extract each section using regex
    final summaryMatch = RegExp(r'\*\*1\. SUMMARY:\*\*(.*?)(?=\*\*2\. IMPORTANT TOPICS:\*\*|$)', dotAll: true).firstMatch(result);
    final topicsMatch = RegExp(r'\*\*2\. IMPORTANT TOPICS:\*\*(.*?)(?=\*\*3\. KEY TERMS:\*\*|$)', dotAll: true).firstMatch(result);
    final termsMatch = RegExp(r'\*\*3\. KEY TERMS:\*\*(.*?)(?=\*\*4\. STUDY ROADMAP:\*\*|$)', dotAll: true).firstMatch(result);
    final roadmapMatch = RegExp(r'\*\*4\. STUDY ROADMAP:\*\*(.*?)(?=\*\*5\. DISCUSSION QUESTIONS:\*\*|$)', dotAll: true).firstMatch(result);
    final questionsMatch = RegExp(r'\*\*5\. DISCUSSION QUESTIONS:\*\*(.*?)$', dotAll: true).firstMatch(result);
    
    if (summaryMatch != null) sections['summary'] = summaryMatch.group(1)?.trim() ?? '';
    if (topicsMatch != null) sections['important_topics'] = topicsMatch.group(1)?.trim() ?? '';
    if (termsMatch != null) sections['key_terms'] = termsMatch.group(1)?.trim() ?? '';
    if (roadmapMatch != null) sections['study_roadmap'] = roadmapMatch.group(1)?.trim() ?? '';
    if (questionsMatch != null) sections['discussion_questions'] = questionsMatch.group(1)?.trim() ?? '';
    
    // If we couldn't parse the sections, return the full result as a fallback
    if (sections.isEmpty) {
      sections['full_content'] = result;
    }
    
    return sections;
  }
  
  Future<List<Map<String, String>>?> generateFlashcards(String pdfText, {int count = 10}) async {
    final prompt = 'Generate exactly $count flashcards based on the following text. '
                   'For each flashcard, provide a "front" (question/term) and "back" (answer/definition). '
                   'Format your response as a list where each flashcard is clearly separated. '
                   'For each flashcard, start with "CARD:" followed by "FRONT:" and then "BACK:" on separate lines:';
    
    final result = await _generateContent(prompt, pdfText);
    if (result == null) return null;
    
    List<Map<String, String>> flashcards = [];
    final cardMatches = RegExp(r'CARD:(?:.|\n)*?FRONT:(.*?)\nBACK:(.*?)(?=\nCARD:|$)', dotAll: true).allMatches(result);
    
    for (var match in cardMatches) {
      if (match.groupCount >= 2) {
        String front = match.group(1)?.trim() ?? '';
        String back = match.group(2)?.trim() ?? '';
        if (front.isNotEmpty && back.isNotEmpty) {
          flashcards.add({
            'front': front,
            'back': back,
          });
        }
      }
    }
    
    return flashcards;
  }

  Future<String?> generateQuestions(String pdfText, {int count = 10, String type = 'mixed', String difficulty = 'medium'}) async {
    String questionTypePrompt;
    String baseType = type;
    
    // No need to parse the type string anymore as we have a separate difficulty parameter
    
    switch (baseType) {
      case 'long_response':
        questionTypePrompt = 'long or short response questions that require written answers';
        break;
      case 'true_false':
        questionTypePrompt = 'true/false questions where the answer is either true or false';
        break;
      case 'multiple_choice':
        questionTypePrompt = 'multiple-choice questions with exactly 4 options (A, B, C, D) where only one is correct';
        break;
      case 'fill_blank':
        questionTypePrompt = 'fill-in-the-blank questions where key words or phrases are missing';
        break;
      case 'mixed':
      default:
        questionTypePrompt = 'a mix of different question types (multiple choice, true/false, short answer)';
        break;
    }
    
    // Define difficulty level instructions
    String difficultyInstructions;
    switch (difficulty) {
      case 'easy':
        difficultyInstructions = 'Make these questions EASY difficulty, focusing on basic concepts, definitions, and straightforward information that is explicitly stated in the text. Questions should test recall and basic understanding.';
        break;
      case 'hard':
        difficultyInstructions = 'Make these questions HARD difficulty, requiring deep understanding, analysis, synthesis of multiple concepts, and application of knowledge. Include questions that test critical thinking and require connecting different parts of the text.';
        break;
      case 'medium':
      default:
        difficultyInstructions = 'Make these questions MEDIUM difficulty, balancing basic recall with some analytical thinking. Questions should test understanding and application of concepts from the text.';
        break;
    }
    
    String prompt;
    
    if (baseType == 'multiple_choice') {
      prompt = 'Generate exactly $count multiple-choice questions with 4 options each. '
              'Each question MUST have exactly 4 options labeled A), B), C), and D). '
              'Each option MUST contain REAL, MEANINGFUL content related to the question, not just placeholders. '
              'Format each question as follows:\n'
              'Q: [Question text]\n'
              'A) [Specific, meaningful option text]\n'
              'B) [Specific, meaningful option text]\n'
              'C) [Specific, meaningful option text]\n'
              'D) [Specific, meaningful option text]\n'
              'CORRECT: [Correct option letter (A, B, C, or D)]\n\n'
              'IMPORTANT REQUIREMENTS:\n'
              '1. The questions should be based *only* on the following text\n'
              '2. Each option MUST contain SPECIFIC CONTENT, not generic placeholders\n'
              '3. Include the correct answer after each question using the CORRECT: prefix\n'
              '4. Make sure all 4 options (A, B, C, D) are provided for EACH question\n'
              '5. $difficultyInstructions';
    } else {
      prompt = 'Generate exactly $count $questionTypePrompt '
              'suitable for an exam, based *only* on the following text. '
              'Present each question on a new line, starting with "Q: ". '
              'For multiple choice questions, list options as A), B), C), D) on separate lines after the question.\n'
              '$difficultyInstructions';
    }
    return await _generateContent(prompt, pdfText);
  }

  Future<String?> checkAnswer(String pdfText, String question, String userAnswer) async {
    final prompt = 'Based *only* on the provided PDF Content below, evaluate '
                   'the following user\'s answer to the question.\n\n'
                   'Question: "$question"\n'
                   'User\'s Answer: "$userAnswer"\n\n'
                   'Is the user\'s answer correct according to the text? '
                   'If it is correct, state "Correct." and briefly explain why. '
                   'If it is incorrect, state "Incorrect." and explain *why* it is incorrect, '
                   'providing the correct information based *strictly* on the provided PDF content.';
    return await _generateContent(prompt, pdfText);
  }
}