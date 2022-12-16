# Simple_KL_study_program_001

15-12-2022
UPDATE INFO: In the next update the nodiskgeometry version shall be REMOVED, instead the manual shall provide addressing guides for both geometry-adhereing and geometry-ignoring system addressing using the same binary. The geometry adherence was kept to retain compatibility with some major VM software (like VBOX) and to retain full legacy system compatibility. The next update may take a while to come out due to the need for this change. However, having only one version to deal with going foward should make it easier to add new entries. Yes, this change does waste a bit of space on the disk in non-geometry adhereing situations but I think that the tradeoff is worth it. And of course, just because the built-in question set is designed with disk geometry in mind (and wasted space), that does not mean that it is not supported anymore, custom question sets can still be whatever (as long as you address them correctly) as the question data is a seperate enitity from the code in some ways.

Sorry for the long time with no updates!



This is a simple x86 real mode program that is designed for Kalaallisut study but (once I get a meaningful description of how to create question disks for it) it can really be used for any type of question-based study.

If you just want to use the program then download the latest from the releases section. Please see the included ProgramUserGuide.odt for instruction on how to get started using this program.

In the future I will also create instructions of how one can make their own disk files with custom questions.

(Note that just because there is no instructions yet does not mean it is not possible; all of the functionality is present in the code and there are some comments in the sourcedisk.asm file explaining a bit of how one would make their own questions so if you want to try without instructions it is certainly possible!


If you encounter any issues, bugs, or just have a suggestion please report them in Issues or send me a message on Discord!


Assembled using NASM

Questions on base program disk are from chapter one of How to Learn Greenlandic by Stian Lybech: oqa.dk
