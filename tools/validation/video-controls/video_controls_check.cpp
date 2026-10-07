#include "settings_manager.h"
#include "tab_video.h"
#include <QApplication>
#include <QComboBox>
#include <QCheckBox>
#include <QFile>
#include <QTemporaryDir>
#include <iostream>
#include <stdexcept>
void check(bool ok,const char *message){if(!ok)throw std::runtime_error(message);std::cout<<"PASS: "<<message<<std::endl;}
int main(int argc,char**argv){
 QApplication app(argc,argv);QTemporaryDir directory;auto &settings=SettingsManager::instance();settings.setConfigDir(directory.path());
 QFile file(settings.configpath());file.open(QIODevice::WriteOnly);file.write("[audio]\nmaster_volume = 0.35\n[video]\nrenderer = \"opengl\"\nrender_scale = 2\nrender_scale_auto = false\nanisotropy = 8\nwindow_w = 1920\nwindow_h = 1080\n");file.close();
 check(settings.load(),"load settings");check(!settings.renderScaleAuto()&&settings.renderScale()==2&&settings.anisotropy()==8,"load manual resolution and anisotropy");
 VideoTab tab;
 check(!settings.renderScaleAuto()&&settings.renderScale()==2,"opening video settings preserves manual scale");
 QComboBox *scale=nullptr,*window=nullptr,*aniso=nullptr;
 for(auto *combo:tab.findChildren<QComboBox*>()){
  if(combo->findText("Auto (window resolution)")>=0)scale=combo;
  if(combo->findText("16x")>=0)aniso=combo;
  if(combo->findText("2560 x 1440")>=0)window=combo;
 }
 check(scale&&aniso&&window,"video options are available");
 scale->setCurrentIndex(1);window->setCurrentIndex(window->findText("2560 x 1440"));
 check(!settings.renderScaleAuto()&&settings.renderScale()==1,"changing window resolution preserves manual internal scale");
 aniso->setCurrentIndex(4);check(settings.anisotropy()==16,"anisotropy choice updates preference");
 check(settings.save()&&settings.load(),"round trip settings");check(!settings.renderScaleAuto()&&settings.renderScale()==1&&settings.anisotropy()==16,"manual scale and filtering persist");
 scale->setCurrentIndex(0);check(settings.renderScaleAuto()&&settings.renderScale()==3,"auto mode derives scale from window height");
 QCheckBox *bilinear = tab.findChild<QCheckBox*>("bilinearFilter");
 QComboBox *renderer = tab.findChild<QComboBox*>("rendererChoice");
 check(bilinear != nullptr, "bilinear control is available");
 bilinear->setChecked(false); check(!aniso->isEnabled(), "anisotropy disabled without bilinear filtering");
 bilinear->setChecked(true); check(aniso->isEnabled(), "anisotropy restored with bilinear filtering");
 check(renderer != nullptr, "renderer control is available");
 renderer->setCurrentIndex(1); check(!aniso->isEnabled(), "anisotropy unavailable with software renderer");
 renderer->setCurrentIndex(2); check(!aniso->isEnabled(), "anisotropy unavailable with Vulkan renderer");
 renderer->setCurrentIndex(0); check(aniso->isEnabled(), "anisotropy restored with OpenGL renderer");
 check(settings.masterVolume() > 0.34f && settings.masterVolume() < 0.36f, "audio preference survives video changes");
 std::cout<<"Launcher settings checks complete"<<std::endl;
}