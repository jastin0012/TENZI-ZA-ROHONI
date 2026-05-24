from docx import Document
from docx.shared import Pt, Mm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml.shared import OxmlElement, qn

# Helper: add a field (e.g., TOC, PAGE)
def add_field_run(paragraph, field_code):
    fld = OxmlElement('w:fldSimple')
    fld.set(qn('w:instr'), field_code)
    r = OxmlElement('w:r')
    t = OxmlElement('w:t')
    t.text = ''
    r.append(t)
    fld.append(r)
    paragraph._p.append(fld)

# Helper: set page number format on a section (roman or arabic), and optionally restart at a number
def set_page_number_format(section, fmt='arabic', start_at=None):
    sectPr = section._sectPr
    pgNumType = sectPr.find(qn('w:pgNumType'))
    if pgNumType is None:
        pgNumType = OxmlElement('w:pgNumType')
        sectPr.append(pgNumType)
    if fmt:
        pgNumType.set(qn('w:fmt'), fmt)
    if start_at is not None:
        pgNumType.set(qn('w:start'), str(start_at))

# Helper: add page number to footer ("Page X of Y")
def add_page_numbers(section):
    footer = section.footer
    if not footer.paragraphs:
        p = footer.add_paragraph()
    else:
        p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER

    # Page X of Y
    run = p.add_run('')
    # PAGE field
    add_field_run(p, 'PAGE')
    p.add_run(' of ')
    add_field_run(p, 'NUMPAGES')

# Create document

document = Document()

# Set base font and paragraph spacing
style = document.styles['Normal']
style.font.name = 'Times New Roman'
style.font.size = Pt(12)
style.paragraph_format.line_spacing = 1.5
style.paragraph_format.space_after = Pt(0)

# Margins per UDOM: Left >= 38mm; Right/Top/Bottom 25mm
section = document.sections[0]
section.left_margin = Mm(38)
section.right_margin = Mm(25)
section.top_margin = Mm(25)
section.bottom_margin = Mm(25)

# Footer page numbering (will be adjusted per section format below)
section.different_first_page_header_footer = True
add_page_numbers(section)
set_page_number_format(section, fmt='roman', start_at=1)

# Cover page (centered blocks)
for _ in range(2):
    document.add_paragraph('')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('THE UNIVERSITY OF DODOMA').bold = True

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('THE COLLEGE OF INFORMATICS AND VIRTUAL EDUCATION').bold = True

document.add_paragraph('')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('DEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING').bold = True

document.add_paragraph('')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('INDUSTRIAL TRAINING REPORT').bold = True

document.add_paragraph('')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('At the Department of Information and Communication Technology (ICT)')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Ravens Consulting Co. Ltd, Dodoma, Tanzania')

document.add_paragraph('')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('By').bold = True

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Student Name: JASTIN SALVATORY PIUS')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Student RegNo: T23-03-13626')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Course Code: CS 231')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Degree Program: Bachelor of Science in Computer Science')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Submitted to: Miss. Lema')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('From: 21 July 2025    To: 13 September 2025')

p = document.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run('Academic Year: 2025/2026')

# Page break to start front matter
from docx.enum.text import WD_BREAK
pb = document.add_paragraph().add_run()
pb.add_break(WD_BREAK.PAGE)

# Table of Contents (auto-update in Word: References > Update Table)
document.add_heading('Table of Contents', level=1)
p = document.add_paragraph()
add_field_run(p, 'TOC \\o "1-3" \\h \\z \\u')

# List of Abbreviations

document.add_heading('List of Abbreviations', level=1)
abbrs = [
    'UDOM — University of Dodoma',
    'CIVE — College of Informatics and Virtual Education',
    'CS — Computer Science',
    'ICT — Information and Communication Technology',
    'IPT — Industrial Practical Training',
    'UI — User Interface',
    'UX — User Experience',
    'UI/UX — User Interface / User Experience',
    'SDK — Software Development Kit',
    'IDE — Integrated Development Environment',
    'JSON — JavaScript Object Notation',
    'API — Application Programming Interface',
    'ADB — Android Debug Bridge',
    'VS Code — Visual Studio Code',
    'AAB — Android App Bundle',
    'APK — Android Application Package',
    'DB — Database',
    'CPU — Central Processing Unit',
    'URL — Uniform Resource Locator',
    'CSV — Comma-Separated Values',
    'QA — Quality Assurance',
    'GPS — Global Positioning System',
    'OS — Operating System',
    'RAM — Random Access Memory',
]
for a in abbrs:
    document.add_paragraph(a, style=None)

# List of Figures and List of Tables placeholders

document.add_heading('List of Figures', level=1)
pf = document.add_paragraph()
add_field_run(pf, 'TOC \\h \\z \\c "Figure"')


document.add_heading('List of Tables', level=1)
pt = document.add_paragraph()
add_field_run(pt, 'TOC \\h \\z \\c "Table"')

# Acknowledgement

document.add_heading('Acknowledgement', level=1)
ack = (
    'I would like to express my sincere gratitude to the management and staff of Ravens Consulting Co. Ltd for their support, '
    'mentorship, and cooperation throughout my industrial training period. My heartfelt appreciation goes to Mr. Joseph '
    'Mwanuke, my supervisor in the Mobile Apps and Games Team, for his exceptional guidance, technical support, and continuous '
    'mentorship. I also extend special thanks to my academic supervisor from the University of Dodoma, College of Informatics '
    'and Virtual Education (CIVE), for her unwavering guidance, feedback, and motivation throughout the training. '
    'I am equally grateful to Mr. Elisha Makoye, Mr. David Fred (CIVE), Mr. Adam Kayenge (CIVE), Mr. Robert Patrick Achimpota (CIVE), '
    'and Mr. Godfrey Mussa (Ravens Consulting Co. Ltd). I further acknowledge Director Augustine Malero of Ravens Consulting Co. Ltd '
    'for providing a conducive learning environment and the opportunity to gain practical industry experience. Finally, I thank my '
    'family and friends for their continuous encouragement and support.'
)
document.add_paragraph(ack)

# Summary

document.add_heading('Summary', level=1)
sumtxt = (
    'This report summarizes my eight-week Industrial Practical Training at Ravens Consulting Co. Ltd (Lawate Building, Dodoma) '
    'from 21 July to 13 September 2025. Assigned to the ICT & Software Development department, I contributed to the design and '
    'implementation of Tenzi za Rohoni, an offline Swahili hymnbook mobile application built with Flutter. My responsibilities '
    'included requirements gathering, UI/UX design, project scaffolding, preparing and integrating a structured JSON hymns dataset, '
    'implementing search and favourites functionality, theming, and adding share/copy features. I performed manual testing on '
    'emulators and physical devices, applied performance optimisations, and prepared documentation and release artifacts. I also '
    'researched audio playback options and licensing constraints for future recordings. The placement enhanced my practical '
    'mobile-development skills, collaborative working, and technical documentation abilities.'
)
document.add_paragraph(sumtxt)

# Section break: Start main body with Arabic numbering starting at 1

document.add_section(WD_SECTION.NEW_PAGE)
body_section = document.sections[-1]
add_page_numbers(body_section)
set_page_number_format(body_section, fmt='arabic', start_at=1)

# 1. Introduction

document.add_heading('1. Introduction', level=1)
intro = (
    'Industrial training is an essential component of the Bachelor of Science in Computer Science program at the University of '
    'Dodoma. It provides students with practical experience in real-world working environments and bridges the gap between '
    'theoretical knowledge and industry practice. This report documents the activities, tasks, and achievements performed during '
    'my industrial training at Ravens Consulting Co. Ltd. The primary project was the development of Tenzi za Rohoni— a digital '
    'hymn book application that supports offline access, searching by title/number, favorites, sharing, and theming.'
)
document.add_paragraph(intro)

# 2. Company Profile

document.add_heading('2. Company Profile and Organizational Chart', level=1)
company_lines = [
    'Name: Ravens Consulting Co. Ltd',
    'Address: Lawate Building, 1st Floor, Room No. 2, P.O. Box 850, Dodoma',
    'Phone: +255 26 232 4558',
    'Email: info@ravensconsulting.co.tz',
    'Website: https://www.ravensconsulting.co.tz',
]
for line in company_lines:
    document.add_paragraph(line)

document.add_heading('Vision', level=2)
document.add_paragraph('To provide reliable ICT, research, and data management solutions that empower individuals and institutions in Tanzania and beyond.')

document.add_heading('Mission', level=2)
document.add_paragraph('To deliver high-quality, data-driven, and innovative ICT and research consulting services that meet clients’ needs.')

document.add_heading('Organizational Structure', level=2)
document.add_paragraph(
    'Ravens Consulting Co. Ltd operates under a hierarchical structure to ensure efficient coordination and quality service delivery. '
    'The structure includes: Director; Heads of Departments (ICT, Research & Data Analysis, Training & Capacity Building, '
    'Administration & Finance); Assistant Heads; and Team Members.'
)

# 3. Body of Report (Weeks 1-8)

document.add_heading('3. Body of Report', level=1)
document.add_paragraph(
    'The body is the main part of the report. Provide evidence of your work (photos captured during IPT). '
    'Include pictures of activities performed and relate them to specific tasks. Use proper figure captions so that the List of Figures updates automatically.'
)
document.add_paragraph(
    '9.1 Work Performed and Achievements: Detail the tasks and projects you performed during the training period. '
    'Each task/project should be described in its own subsection with objectives, tools/technologies, steps taken, results, and supporting evidence (screenshots/photos).'
)
document.add_paragraph(
    '9.2 New Knowledge and Skills Learned: Describe the new skills or knowledge acquired that you did not have before IPT. '
    'Demonstrate how you applied these skills to solve specific problems you encountered during the placement.'
)

# Week 1

document.add_heading('3.1 Week 1 — Orientation, Setup & Requirements Gathering', level=2)
week1_points = [
    'Orientation with staff, environment, and expectations; documented office layout and team roles.',
    'Defined app features and flow (list, search, favorites, share/copy, placeholder audio UI).',
    'Researched Tenzi za Rohoni structure and defined JSON fields (song_number, title, stanza_n, chorus).',
    'Chose Flutter; installed SDK and IDE (VS Code); verified environment with flutter doctor (no errors).',
    'Initialized GitHub repo and project board with issues and milestones.',
]
for pt in week1_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('New Knowledge and Skills Learned', level=3)
week1_skills = [
    'Understanding organizational structures and workplace orientation.',
    'Feature design and user flow planning for mobile apps.',
    'Data analysis and structuring for digital hymn content.',
    'Flutter environment setup and verification.',
    'Version control and project management with GitHub.',
]
for sk in week1_skills:
    document.add_paragraph(f'- {sk}')

# Week 2

document.add_heading('3.2 Week 2 — UI/UX Design & App Skeleton', level=2)
week2_points = [
    'Designed wireframes (home, lyrics, search, favorites, settings, recents, about, feedback) in Figma.',
    'Initialized Flutter project with clear structure (screens, widgets, services, utils, assets).',
    'Set up navigation (home > detail > favorites) and parameter passing.',
    'Built static UI screens to validate styling and responsiveness.',
]
for pt in week2_points:
    document.add_paragraph(f'- {pt}')

document.add_paragraph('Figma design link: https://www.figma.com/design/ulJufvWPX4B8f1h52hDGZg/offline--spritual-hymns?node-id=8-2&p=f&t=3DyMrvB9vTYgpwEn-0')

document.add_heading('Skills and Knowledge Learned', level=3)
for sk in ['Wireframing and UX planning.', 'Project scaffolding and navigation.', 'Static UI prototyping.']:
    document.add_paragraph(f'- {sk}')

# Week 3

document.add_heading('3.3 Week 3 — Integrating Hymn Data', level=2)
week3_points = [
    'Prepared assets/json/tenzi.json dataset (cleaned and structured).',
    'Implemented Hymn model and HymnService to load/parse/cache JSON.',
    'Linked list items to detail screen with full hymn content.',
]
for pt in week3_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('New Knowledge and Skills Learned', level=3)
for sk in [
    'Cleaning raw text and converting to structured JSON.',
    'Creating data models/services for efficient JSON handling.',
    'Integrating data with UI and navigation.',
]:
    document.add_paragraph(f'- {sk}')

# Week 4

document.add_heading('3.4 Week 4 — Favorites and Persistent Storage', level=2)
week4_points = [
    'Implemented FavoritesManager with streams and SharedPreferences (key: favorites_v2).',
    'Updated HymnCard and HymnDetailPage to toggle and reflect favorite state (optimistic UI).',
    'Added Favorites tab subscribing to favorites stream.',
]
for pt in week4_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('Skills and Knowledge Learned', level=3)
for sk in ['Dart streams', 'SharedPreferences persistence', 'Optimistic UI updates', 'Cross-screen state sync']:
    document.add_paragraph(f'- {sk}')

# Week 5

document.add_heading('3.5 Week 5 — Audio Playback Exploration', level=2)
week5_points = [
    'Prototyped audio UI panel (play/pause, progress).',
    'Evaluated just_audio and audio_session; drafted asset/URL mapping plan.',
    'Investigated licensing; kept controls as placeholders pending cleared audio.',
]
for pt in week5_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('Skills and Knowledge Learned', level=3)
for sk in ['Package research and prototyping', 'Legal/licensing documentation']:
    document.add_paragraph(f'- {sk}')

# Week 6

document.add_heading('3.6 Week 6 — Advanced Features and Theming', level=2)
week6_points = [
    'Implemented theme toggle with persisted preference.',
    'Added share/copy hymn text using share_plus.',
    'Implemented debounced search with highlighted matches and improved scrolling.',
    'Polished UX (spacing, icons, touch targets, responsiveness).',
]
for pt in week6_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('Achievements', level=3)
for sk in ['Clear search highlighting', 'Smooth scrolling and responsiveness']:
    document.add_paragraph(f'- {sk}')

# Week 7

document.add_heading('3.7 Week 7 — Testing and Optimization', level=2)
week7_points = [
    'Manual testing on emulators and physical devices.',
    'Fixed bugs/crashes; added null checks and minimized unnecessary rebuilds.',
    'Optimized performance with ListView.builder, JSON caching, and debounced search.',
]
for pt in week7_points:
    document.add_paragraph(f'- {pt}')

document.add_heading('Achievements', level=3)
for sk in [
    'All manual tests passed; no crashes observed.',
    'Responsive search; correct highlights.',
    'Smooth lists on low-end devices.',
    'Favorites persist/update across screens.',
    'Stable under rotation and theme changes.',
]:
    document.add_paragraph(f'- {sk}')

# Week 8

document.add_heading('3.8 Week 8 — Documentation and Presentation', level=2)
week8_points = [
    'Prepared comprehensive project report and user guide (architecture, installation, usage, screenshots, limitations).',
    'Improved inline comments and READMEs for key modules (theme, hymn service, favorites, search).',
    'Integrated ads (banner at bottom navigation, interstitial on exit of hymn detail).',
    'Built, signed, and uploaded .aab to Google Play Console; published app (link below).',
]
for pt in week8_points:
    document.add_paragraph(f'- {pt}')

document.add_paragraph('Google Play: https://play.google.com/store/apps/details?id=com.rav850418082.tenzi_za_rohoni&pcampaignid=web_share')

# 4. Conclusions and Recommendations

document.add_heading('4. Conclusions and Recommendations', level=1)
document.add_paragraph(
    'In this last section, conclude your training and state recommendations regarding: benefits, weaknesses, the level and appropriateness '
    'of the work performed, and the length of the training period. Provide clear, actionable suggestions for both the host organization '
    'and the university.'
)

document.add_heading('Conclusions', level=2)
concl = (
    'The Industrial Practical Training period offered valuable hands-on experience bridging classroom theory and workplace '
    'practice. Activities included requirements analysis, design, coding, documentation, testing, and release preparation. '
    'Usable outputs (code, documentation, user guides) were produced for handover. Organizational approvals (e.g., audio licensing '
    'or store publishing) are beyond trainee scope. Overall, IPT was beneficial and should continue with improved coordination, '
    'clearer pre-placement preparation, and a stronger handoff process.'
)
document.add_paragraph(concl)

document.add_heading('Recommendations', level=2)
recs = [
    'Ravens Consulting Co. Ltd (Dodoma): Maintain an organized archive of project files, reports, configuration notes, and screenshots for future work and handovers.',
    'University of Dodoma: Require short post-IPT presentations for students to share experiences and lessons learned.',
]
for r in recs:
    document.add_paragraph(f'- {r}')

# 5. References

document.add_heading('5. References', level=1)
refs = [
    'Android Developers. (2023). Publish your app. https://developer.android.com/studio/publish (Last updated 2023-11-15)',
    'Flutter. (2025). Get started - install. https://flutter.dev/docs/get-started/install (Last updated 2025-10-28)',
    'Flutter. (accessed 2025). Persistence and JSON. https://docs.flutter.dev/cookbook/persistence/json',
    'FlutterFlow. (2025). https://flutterflow.io',
    'go_router (Flutter routing). (accessed 2025). https://pub.dev/packages/go-router',
    'GitHub. (accessed 2025). Git & project hosting. https://github.com/',
    'Hive package (Flutter local storage). (accessed 2025). https://pub.dev/packages/hive',
    'just_audio package (Flutter). (accessed 2025). https://pub.dev/packages/just_audio',
    'Material 3 Theme Builder. (accessed 2025). https://m3.material.io/theme-builder#/custom',
    'share_plus package (Flutter). (accessed 2025). https://pub.dev/packages/share_plus',
    'shared_preferences package (Flutter). (accessed 2025). https://pub.dev/packages/shared_preferences',
    'sqflite package (Flutter SQLite). (accessed 2025). https://pub.dev/packages/sqflite',
    'Sentry (error reporting). (2025). https://sentry.io/for/flutter/',
    'Stack Overflow. (2025). https://stackoverflow.com/',
]
for ref in refs:
    document.add_paragraph(f'- {ref}')

# 6. Appendices

document.add_heading('6. Appendices', level=1)
appendix = [
    'Appendix A: Logbook',
    'Appendix B: Arrival Note',
]
for ap in appendix:
    document.add_paragraph(ap)

# Save document
output_path = 'Jastin_IPT_Report_2025_UDOM_CIVE.docx'
document.save(output_path)
print(f'Generated: {output_path}')
