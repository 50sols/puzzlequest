'use strict';
(() => {
    const form = document.getElementById('setup-form');if(!form)return;
    let step=1, probed=false;
    const steps=[...document.querySelectorAll('[data-step]')];
    const buttons=[...document.querySelectorAll('[data-indicator]')];
    function goto(n) {
        step=n;
        steps.forEach(el=>el.hidden=Number(el.dataset.step)!==n);
        buttons.forEach(el=>el.classList.toggle('current',Number(el.dataset.indicator)===n));
        window.scrollTo(0,0);
    }
    const check=(names)=>names.every(name=>{const e=form.elements.namedItem(name);return e && e.checkValidity();});
    document.querySelectorAll('[data-prev]').forEach(el=>el.addEventListener('click',()=>goto(Number(el.dataset.prev))));
    document.querySelectorAll('[data-next]').forEach(el=>el.addEventListener('click',()=>{
        if(step===1&&!check(['install_key'])){
            const feedback=document.getElementById('step-feedback');
            if(feedback) feedback.textContent='أدخل رمز التثبيت الكامل من install.key (40 حرفًا على الأقل).';
            form.elements.install_key.reportValidity();return;
        }
        const feedback=document.getElementById('step-feedback');
        if(feedback) feedback.textContent='';
        if(step===2&&!probed)return;
        goto(Number(el.dataset.next));
    }));
    const probe=document.getElementById('probe');
    if(probe){
        const dbFields=['url','host','port','database','username','password'];
        const reset=()=>{probed=false;document.getElementById('db-next').disabled=true;document.getElementById('probe-result').textContent='يلزم إعادة الاختبار بعد تعديل الاتصال.';};
        dbFields.forEach(name=>form.elements.namedItem(name).addEventListener('input',reset));
        probe.addEventListener('click',async()=>{
            if(!check(['install_key',...dbFields])){for(const name of ['install_key',...dbFields]){const e=form.elements.namedItem(name);if(!e.checkValidity()){e.reportValidity();break;}}return;}
            probe.disabled=true;const feedback=document.getElementById('probe-result');feedback.textContent='جارٍ اختبار الاتصال...';
            try{
                const data=new FormData(form);data.set('action','probe');
                const response=await fetch(window.location.href,{method:'POST',body:data,credentials:'same-origin',headers:{Accept:'application/json'}});
                const result=await response.json();probed=Boolean(response.ok && result.ok);
                feedback.textContent=result.message||'تعذر إجراء الاختبار.';
            }catch(error){probed=false;feedback.textContent='تعذر الاتصال بالخادم لإجراء الاختبار.';}
            document.getElementById('db-next').disabled=!probed;probe.disabled=false;
        });
    }
    form.addEventListener('submit',event=>{
        if(!probed || !check(['admin_email','admin_password'])){event.preventDefault();return;}
        const finish=document.getElementById('finish');finish.disabled=true;finish.textContent='جارٍ تنفيذ التثبيت...';
    });
    goto(1);
})();
